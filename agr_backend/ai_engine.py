"""
ai_engine.py
-------------
Same AI pipeline as the Streamlit app, with Streamlit removed.
Every feature has an offline fallback, so it works even without a Gemini key.
"""
import io
import re
import unicodedata
from functools import lru_cache

from PIL import Image, ImageOps, ImageEnhance

import config

CATEGORIES = [
    "Textiles & Sarees", "Pottery & Terracotta", "Wooden Crafts",
    "Bamboo & Cane", "Jewelry", "Home Décor", "Bags & Accessories",
    "Paintings & Wall Art", "Toys & Dolls", "Other Handicraft",
]
FALLBACK_CATEGORY = "Other Handicraft"

# label -> (language code, English name)
LANGUAGES = {
    "English": ("en-IN", "English"),
    "हिंदी (Hindi)": ("hi-IN", "Hindi"),
    "मराठी (Marathi)": ("mr-IN", "Marathi"),
    "தமிழ் (Tamil)": ("ta-IN", "Tamil"),
    "తెలుగు (Telugu)": ("te-IN", "Telugu"),
    "বাংলা (Bengali)": ("bn-IN", "Bengali"),
    "ગુજરાતી (Gujarati)": ("gu-IN", "Gujarati"),
    "ಕನ್ನಡ (Kannada)": ("kn-IN", "Kannada"),
    "മലയാളം (Malayalam)": ("ml-IN", "Malayalam"),
    "ਪੰਜਾਬੀ (Punjabi)": ("pa-IN", "Punjabi"),
    "ଓଡ଼ିଆ (Odia)": ("or-IN", "Odia"),
    "اردو (Urdu)": ("ur-IN", "Urdu"),
    "অসমীয়া (Assamese)": ("as-IN", "Assamese"),
    "कोंकणी (Konkani)": ("kok-IN", "Konkani"),
}
DEFAULT_LANGUAGE_LABEL = "English"


# ----------------------------------------------------------------------
# Gemini helpers
# ----------------------------------------------------------------------
def is_gemini_available() -> bool:
    if not config.GEMINI_API_KEY:
        return False
    try:
        import google.generativeai  # noqa: F401
        return True
    except ImportError:
        return False


def _get_gemini_model():
    import google.generativeai as genai
    genai.configure(api_key=config.GEMINI_API_KEY)
    return genai.GenerativeModel(config.GEMINI_MODEL)


# ----------------------------------------------------------------------
# 1. Background removal
# ----------------------------------------------------------------------
def resize_for_processing(image: Image.Image, max_dim: int = 2000) -> Image.Image:
    w, h = image.size
    if max(w, h) <= max_dim:
        return image
    scale = max_dim / max(w, h)
    return image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)


@lru_cache(maxsize=1)
def _get_rembg_session():
    """Loads the rembg model once and reuses it (this is what keeps it fast)."""
    from rembg import new_session
    return new_session(config.REMBG_MODEL or "u2net")


def remove_background(image: Image.Image, matte_size: int = 800) -> Image.Image:
    original_rgb = image.convert("RGB")
    try:
        session = _get_rembg_session()
        from rembg import remove as rembg_remove

        small = resize_for_processing(original_rgb, max_dim=matte_size)
        buf = io.BytesIO()
        small.save(buf, format="PNG")
        result_bytes = rembg_remove(buf.getvalue(), session=session)
        small_cutout = Image.open(io.BytesIO(result_bytes)).convert("RGBA")

        alpha_full = small_cutout.split()[-1].resize(original_rgb.size, Image.LANCZOS)
        original_rgba = original_rgb.convert("RGBA")
        original_rgba.putalpha(alpha_full)

        white_bg = Image.new("RGBA", original_rgb.size, (255, 255, 255, 255))
        white_bg.paste(original_rgba, (0, 0), original_rgba)
        enhanced = white_bg.convert("RGB")
    except Exception:
        enhanced = original_rgb

    enhanced = ImageOps.autocontrast(enhanced, cutoff=1)
    enhanced = ImageEnhance.Brightness(enhanced).enhance(1.05)
    enhanced = ImageEnhance.Color(enhanced).enhance(1.1)
    enhanced = ImageEnhance.Sharpness(enhanced).enhance(1.15)
    return enhanced.convert("RGBA")


# ----------------------------------------------------------------------
# 2. Voice transcription
# ----------------------------------------------------------------------
def transcribe_audio_gemini(audio_bytes: bytes, mime_type: str):
    """Returns (transcript, detected_language) or None on failure."""
    if not is_gemini_available():
        return None
    try:
        model = _get_gemini_model()
        prompt = (
            "Transcribe this voice recording exactly as spoken. The speaker is "
            "describing a handmade product for an e-commerce listing, likely in "
            "an Indian regional language. Respond in this exact format:\n"
            "LANGUAGE: <detected language name in English>\n"
            "TRANSCRIPT: <transcription in its original language>"
        )
        response = model.generate_content([
            prompt,
            {"mime_type": mime_type or "audio/wav", "data": audio_bytes},
        ])
        text = response.text or ""
        lang_match = re.search(r"LANGUAGE:\s*(.+)", text)
        transcript_match = re.search(r"TRANSCRIPT:\s*(.+)", text, re.DOTALL)
        if transcript_match:
            transcript = transcript_match.group(1).strip()
            language = lang_match.group(1).strip() if lang_match else "Unknown"
            return transcript, language
    except Exception:
        pass
    return None


def _prepare_wav_for_recognition(audio_bytes: bytes) -> bytes:
    """Converts any audio format to 16kHz mono WAV (needs ffmpeg installed)."""
    from pydub import AudioSegment

    audio = AudioSegment.from_file(io.BytesIO(audio_bytes))
    audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
    try:
        import numpy as np
        import noisereduce as nr

        samples = np.array(audio.get_array_of_samples()).astype(np.float32)
        reduced = nr.reduce_noise(y=samples, sr=16000)
        audio = AudioSegment(
            reduced.astype(np.int16).tobytes(),
            frame_rate=16000, sample_width=2, channels=1,
        )
    except ImportError:
        pass
    out = io.BytesIO()
    audio.export(out, format="wav")
    return out.getvalue()


def transcribe_offline(audio_bytes: bytes, lang_code: str, lang_name: str):
    """Fallback using speech_recognition. Returns (transcript, language, error)."""
    try:
        import speech_recognition as sr
    except ImportError:
        return None, None, "Offline transcription isn't installed (pip install SpeechRecognition)."

    try:
        wav_bytes = _prepare_wav_for_recognition(audio_bytes)
    except ImportError:
        return None, None, "Audio conversion isn't installed (pip install pydub, and install ffmpeg)."
    except Exception:
        return None, None, "Couldn't process that recording. Please record again."

    try:
        recognizer = sr.Recognizer()
        with sr.AudioFile(io.BytesIO(wav_bytes)) as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.3)
            audio_data = recognizer.record(source)
        transcript = recognizer.recognize_google(audio_data, language=lang_code)
        return transcript, lang_name, None
    except sr.UnknownValueError:
        return None, None, "Couldn't make out any speech. Please re-record in a quieter place, or type the description."
    except sr.RequestError:
        return None, None, "Couldn't reach the transcription service. Check the internet connection."
    except Exception:
        return None, None, "Something went wrong transcribing. Please re-record or type the description."


# ----------------------------------------------------------------------
# 3. Catalog copy
# ----------------------------------------------------------------------
def extract_product_name(raw_text: str) -> str:
    words = re.findall(r"[A-Za-z]+", raw_text)
    if not words:
        return "Handmade Product"
    return " ".join(w.capitalize() for w in words[:4])


def extract_material(raw_text: str) -> str:
    known = [
        "cotton", "silk", "wool", "jute", "bamboo", "cane", "wood", "terracotta",
        "clay", "brass", "copper", "silver", "leather", "wax", "stone", "bead",
        "handloom", "khadi",
    ]
    lowered = raw_text.lower()
    found = [m.capitalize() for m in known if m in lowered]
    return ", ".join(found) if found else "Traditional handmade materials"


def generate_ai_description(raw_text: str, category: str, material: str, source_language: str):
    """Returns (product_name, english_desc, hindi_desc) or None on failure."""
    if not is_gemini_available():
        return None
    try:
        model = _get_gemini_model()
        prompt = f"""You are a professional e-commerce copywriter for an Indian artisan marketplace.
An artisan described their handmade product in {source_language}:

"{raw_text}"

Category: {category}
Material mentioned: {material}

Write:
1. A short, appealing product name (5-8 words)
2. An SEO-friendly English product description (60-100 words) that highlights
   craftsmanship, material, and cultural authenticity, suitable for online buyers.
3. The same description translated naturally into Hindi (not a literal translation).

Respond in exactly this format with no extra commentary:
NAME: <product name>
ENGLISH: <english description>
HINDI: <hindi description>"""
        response = model.generate_content(prompt)
        text = response.text or ""
        name_match = re.search(r"NAME:\s*(.+)", text)
        eng_match = re.search(r"ENGLISH:\s*(.+?)(?=HINDI:|$)", text, re.DOTALL)
        hin_match = re.search(r"HINDI:\s*(.+)", text, re.DOTALL)
        if eng_match and hin_match:
            name = name_match.group(1).strip() if name_match else extract_product_name(raw_text)
            return name, eng_match.group(1).strip(), hin_match.group(1).strip()
    except Exception:
        pass
    return None


def template_description(raw_text: str, category: str, material: str):
    """Offline fallback: simple template. Returns (name, english_desc, hindi_desc)."""
    name = extract_product_name(raw_text)
    mat = material or extract_material(raw_text)
    english = (
        f"Handmade {category.lower()} crafted from {mat.lower()}. {raw_text.strip()} "
        f"Each piece reflects traditional artisan craftsmanship and is made with care."
    )
    hindi = translate_text(english, "हिंदी (Hindi)") or ""
    return name, english, hindi


# ----------------------------------------------------------------------
# 3b. Translation
# ----------------------------------------------------------------------
def _resolve_language(label: str):
    """Matches a stored language label to LANGUAGES. Returns (code, english_name) or (None, None)."""
    if not label:
        return None, None
    normalized = unicodedata.normalize("NFC", label.strip())
    for key, (code, name) in LANGUAGES.items():
        if unicodedata.normalize("NFC", key) == normalized:
            return code, name
    match = re.search(r"\(([^)]+)\)", normalized)
    candidate = (match.group(1).strip() if match else normalized).lower()
    for code, name in LANGUAGES.values():
        if name.lower() == candidate:
            return code, name
    return None, None


def language_display_name(label: str) -> str:
    _, name = _resolve_language(label)
    return name or label


def _translate_offline(text: str, iso_code: str):
    try:
        from deep_translator import GoogleTranslator
    except ImportError:
        return None
    try:
        translated = GoogleTranslator(source="en", target=iso_code).translate(text)
        return translated.strip() if translated else None
    except Exception:
        return None


def translate_text(text: str, target_label: str):
    """Translates English text into the target language. Returns None if the
    target is English, can't be resolved, or both translation routes fail."""
    if not text or not text.strip():
        return None
    target_code, target_name = _resolve_language(target_label)
    if not target_code or target_name.lower() == "english":
        return None
    iso_code = target_code.split("-")[0]

    if is_gemini_available():
        try:
            model = _get_gemini_model()
            prompt = (
                f"Translate the following e-commerce product description naturally "
                f"into {target_name}. Translate the meaning, not word-for-word. "
                f"Respond with ONLY the translated text.\n\n{text}"
            )
            translated = (model.generate_content(prompt).text or "").strip()
            if translated:
                return translated
        except Exception:
            pass
    return _translate_offline(text, iso_code)


# ----------------------------------------------------------------------
# 4. Dynamic pricing
# ----------------------------------------------------------------------
_CATEGORY_MULTIPLIER = {
    "Textiles & Sarees": 1.6, "Pottery & Terracotta": 1.3, "Wooden Crafts": 1.5,
    "Bamboo & Cane": 1.3, "Jewelry": 1.8, "Home Décor": 1.4,
    "Bags & Accessories": 1.5, "Paintings & Wall Art": 1.7,
    "Toys & Dolls": 1.3, "Other Handicraft": 1.35,
}
_SIZE_MULTIPLIER = {"Small": 1.0, "Medium": 1.25, "Large / Detailed": 1.6}


def predict_price(category: str, size: str, raw_cost: float, labor_cost: float) -> int:
    base_cost = max(raw_cost, 0) + max(labor_cost, 0)
    if base_cost <= 0:
        return 0
    cat_mult = _CATEGORY_MULTIPLIER.get(category, 1.35)
    size_mult = _SIZE_MULTIPLIER.get(size, 1.0)
    return int(round(base_cost * cat_mult * size_mult / 10.0) * 10)
