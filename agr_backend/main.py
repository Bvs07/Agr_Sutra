"""
AGR Sutra backend (FastAPI).
Run:  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
Docs: http://localhost:8000/docs  (interactive page to try every endpoint)
"""
import io
import math
import os
import re
import secrets
import time
from typing import List, Optional

import numpy as np
import pandas as pd
from fastapi import (Depends, FastAPI, File, Form, HTTPException, Query,
                     Response, UploadFile)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from PIL import Image
from pydantic import BaseModel, Field

import ai_engine as ai
import config
import data_store as ds
from security import (create_access_token, create_signup_token, decode_token,
                      get_current_user, require_role)

app = FastAPI(title="AGR Sutra API", version="1.0")

# Open CORS so Flutter-web (Chrome) testing works. Restrict this before a public release.
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/images", StaticFiles(directory=ds.IMAGES_DIR), name="images")


# =====================================================================
# Helpers
# =====================================================================
def clean(v):
    """Turns pandas/numpy values into plain JSON-safe values (NaN -> None)."""
    if isinstance(v, dict):
        return {k: clean(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [clean(x) for x in v]
    if isinstance(v, np.generic):
        v = v.item()
    if v is pd.NA or v is pd.NaT:
        return None
    if isinstance(v, float) and math.isnan(v):
        return None
    if isinstance(v, pd.Timestamp):
        return v.isoformat()
    return v


def to_int(v, default=0) -> int:
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


def image_url(path) -> Optional[str]:
    if isinstance(path, str) and path:
        return "/images/" + os.path.basename(path)
    return None


def user_names() -> dict:
    df = ds.load_users()
    if df.empty:
        return {}
    return dict(zip(df["user_id"], df["full_name"].fillna("")))


def public_user(u: dict) -> dict:
    """What the app may see about ANOTHER user (no phone / email)."""
    return clean({
        "user_id": u.get("user_id"), "full_name": u.get("full_name"),
        "pin_code": u.get("pin_code"),
        "latitude": u.get("latitude"), "longitude": u.get("longitude"),
    })


def product_out(row: dict, names: dict, ratings: pd.DataFrame) -> dict:
    pid = row["product_id"]
    avg, cnt = 0.0, 0
    if pid in ratings.index:
        avg = float(ratings.loc[pid, "avg_rating"])
        cnt = int(ratings.loc[pid, "review_count"])
    return clean({
        "product_id": pid, "seller_id": row.get("seller_id"),
        "seller_name": names.get(row.get("seller_id"), ""),
        "product_name": row.get("product_name"), "category": row.get("category"),
        "material": row.get("material"), "language": row.get("language"),
        "price": to_int(row.get("price")), "stock": to_int(row.get("stock")),
        "english_desc": row.get("english_desc"), "hindi_desc": row.get("hindi_desc"),
        "image_url": image_url(row.get("image_path")), "status": row.get("status"),
        "created_at": row.get("created_at"), "avg_rating": avg, "review_count": cnt,
    })


def valid_email(email: str) -> bool:
    return bool(re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email or ""))


# Phone rule (same as the Streamlit app): 10 digits, or +91 followed by 10 digits
_PLAIN_PHONE = re.compile(r"^\d{10}$")
_STD_PHONE = re.compile(r"^\+91\d{10}$")
PHONE_ERROR = ("Enter a valid mobile number: exactly 10 digits (e.g. 9876543210), "
               "or +91 followed by 10 digits (e.g. +919876543210).")


def normalize_phone(phone: str) -> str:
    cleaned = re.sub(r"[\s\-()]", "", phone or "")
    if _STD_PHONE.match(cleaned) or _PLAIN_PHONE.match(cleaned):
        return cleaned
    raise HTTPException(400, PHONE_ERROR)


# =====================================================================
# Meta / health
# =====================================================================
@app.get("/health")
def health():
    return {"status": "ok", "gemini": ai.is_gemini_available()}


@app.get("/meta")
def meta():
    """Lists the app needs on startup: categories, languages, sizes, etc."""
    return {
        "categories": ai.CATEGORIES,
        "languages": list(ai.LANGUAGES.keys()),
        "sizes": config.SIZES,
        "payment_methods": config.PAYMENT_METHODS,
        "order_statuses": config.ORDER_STATUSES,
    }


# =====================================================================
# Auth: send OTP -> verify OTP -> (new users) register
# =====================================================================
_otp_store: dict = {}  # key -> {"otp", "exp", "attempts"}


class OtpRequest(BaseModel):
    phone: Optional[str] = None
    email: Optional[str] = None


class OtpVerify(BaseModel):
    phone: Optional[str] = None
    email: Optional[str] = None
    otp: str


def _otp_key(phone: Optional[str], email: Optional[str]):
    if phone and phone.strip():
        p = normalize_phone(phone)
        return f"phone:{p}", p, ""
    if email and email.strip():
        e = email.strip().lower()
        if not valid_email(e):
            raise HTTPException(400, "Enter a valid email address.")
        return f"email:{e}", "", e
    raise HTTPException(400, "Enter a mobile number or an email address.")


@app.post("/auth/send-otp")
def send_otp(body: OtpRequest):
    key, phone, email = _otp_key(body.phone, body.email)
    otp = f"{secrets.randbelow(1_000_000):06d}"
    _otp_store[key] = {"otp": otp, "exp": time.time() + config.OTP_EXPIRE_SECONDS, "attempts": 0}
    # DEMO MODE: no SMS/email is sent, the OTP is returned so you can test.
    # For a real release, send it with an SMS/email provider and REMOVE "demo_otp" from this response.
    return {"message": "OTP generated (demo mode: no SMS/email is sent).",
            "demo_otp": otp, "phone": phone, "email": email,
            "expires_in_seconds": config.OTP_EXPIRE_SECONDS}


@app.post("/auth/verify-otp")
def verify_otp(body: OtpVerify):
    key, phone, email = _otp_key(body.phone, body.email)
    entry = _otp_store.get(key)
    if not entry or time.time() > entry["exp"]:
        _otp_store.pop(key, None)
        raise HTTPException(400, "OTP expired. Please request a new one.")
    entry["attempts"] += 1
    if entry["attempts"] > config.OTP_MAX_ATTEMPTS:
        _otp_store.pop(key, None)
        raise HTTPException(429, "Too many attempts. Please request a new OTP.")
    if not secrets.compare_digest(entry["otp"], (body.otp or "").strip()):
        raise HTTPException(400, "Incorrect code. Please try again.")
    _otp_store.pop(key, None)

    existing = ds.get_user_by_contact(phone=phone, email=email)
    if existing:
        return {"is_new_user": False, "access_token": create_access_token(existing["user_id"]),
                "user": clean(existing)}
    return {"is_new_user": True, "signup_token": create_signup_token(phone, email)}


class RegisterBody(BaseModel):
    signup_token: str
    full_name: str = Field(min_length=1)
    phone: Optional[str] = ""
    email: Optional[str] = ""
    pin_code: Optional[str] = ""
    language: str = "English"
    role: str


@app.post("/auth/register")
def register(body: RegisterBody):
    claims = decode_token(body.signup_token, "signup")
    if body.role not in ("Seller", "Buyer"):
        raise HTTPException(400, "Role must be Seller or Buyer.")
    phone = claims.get("phone") or ""
    email = claims.get("email") or ""
    # The other contact (not OTP-verified) is optional but must be valid if given.
    if not phone and body.phone and body.phone.strip():
        phone = normalize_phone(body.phone)
    if not email and body.email and body.email.strip():
        if not valid_email(body.email.strip()):
            raise HTTPException(400, "Enter a valid email address.")
        email = body.email.strip().lower()
    code, _ = ai._resolve_language(body.language)
    language = body.language if code else ai.DEFAULT_LANGUAGE_LABEL
    user = ds.create_or_update_user(
        full_name=body.full_name.strip(), phone=phone, email=email,
        pin_code=(body.pin_code or "").strip(), language=language, role=body.role)
    return {"access_token": create_access_token(user["user_id"]), "user": clean(user)}


# =====================================================================
# Users
# =====================================================================
def _me_payload(user: dict) -> dict:
    if user.get("role") == "Seller":
        avg, cnt = ds.get_seller_rating(user["user_id"])
    else:
        avg, cnt = ds.get_buyer_rating(user["user_id"])
    out = clean(user)
    out["rating"] = {"average": avg, "count": cnt}
    return out


@app.get("/users/me")
def get_me(user: dict = Depends(get_current_user)):
    return _me_payload(user)


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    pin_code: Optional[str] = None
    language: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@app.put("/users/me")
def update_me(body: ProfileUpdate, user: dict = Depends(get_current_user)):
    fields = {}
    if body.full_name is not None and body.full_name.strip():
        fields["full_name"] = body.full_name.strip()
    if body.phone is not None and body.phone.strip():
        fields["phone"] = normalize_phone(body.phone)
    if body.email is not None and body.email.strip():
        if not valid_email(body.email.strip()):
            raise HTTPException(400, "Enter a valid email address.")
        fields["email"] = body.email.strip().lower()
    if body.pin_code is not None:
        fields["pin_code"] = body.pin_code.strip()
    if body.language is not None:
        code, _ = ai._resolve_language(body.language)
        if not code:
            raise HTTPException(400, "Unsupported language.")
        fields["language"] = body.language
    if body.latitude is not None and body.longitude is not None:
        fields["latitude"], fields["longitude"] = body.latitude, body.longitude
    updated = ds.update_user_profile(user["user_id"], **fields)
    return _me_payload(updated)


# =====================================================================
# AI endpoints
# =====================================================================
@app.post("/ai/remove-background")
def ai_remove_background(image: UploadFile = File(...), user: dict = Depends(get_current_user)):
    """Send a photo, get back a cleaned PNG (white background)."""
    try:
        img = Image.open(io.BytesIO(image.file.read()))
        img.load()
    except Exception:
        raise HTTPException(400, "That file isn't a valid image.")
    result = ai.remove_background(img)
    buf = io.BytesIO()
    result.save(buf, format="PNG")
    return Response(content=buf.getvalue(), media_type="image/png")


@app.post("/ai/transcribe")
def ai_transcribe(audio: UploadFile = File(...), language: str = Form(""),
                  user: dict = Depends(get_current_user)):
    """Voice -> text. `language` (optional) is a label from /meta, used only by the offline fallback."""
    data = audio.file.read()
    if not data:
        raise HTTPException(400, "Empty audio file.")
    result = ai.transcribe_audio_gemini(data, audio.content_type or "audio/wav")
    if result:
        transcript, detected = result
        return {"transcript": transcript, "language": detected, "error": None}
    code, name = ai.LANGUAGES.get(language, ai.LANGUAGES[ai.DEFAULT_LANGUAGE_LABEL])
    transcript, detected, error = ai.transcribe_offline(data, code, name)
    return {"transcript": transcript, "language": detected, "error": error}


class CatalogCopyIn(BaseModel):
    raw_text: str = Field(min_length=1)
    category: str = ai.FALLBACK_CATEGORY
    material: str = ""
    source_language: str = "English"


@app.post("/ai/catalog-copy")
def ai_catalog_copy(body: CatalogCopyIn, user: dict = Depends(get_current_user)):
    category = body.category if body.category in ai.CATEGORIES else ai.FALLBACK_CATEGORY
    material = body.material.strip() or ai.extract_material(body.raw_text)
    result = ai.generate_ai_description(body.raw_text, category, material, body.source_language)
    used_ai = result is not None
    if result is None:
        result = ai.template_description(body.raw_text, category, material)
    name, english, hindi = result
    return {"product_name": name, "english_desc": english, "hindi_desc": hindi,
            "material": material, "category": category, "used_ai": used_ai}


class PriceIn(BaseModel):
    category: str
    size: str = "Small"
    raw_cost: float = Field(ge=0)
    labor_cost: float = Field(ge=0)


@app.post("/ai/suggest-price")
def ai_suggest_price(body: PriceIn, user: dict = Depends(get_current_user)):
    return {"suggested_price": ai.predict_price(body.category, body.size, body.raw_cost, body.labor_cost)}


class TranslateIn(BaseModel):
    text: str
    target_language: str


@app.post("/ai/translate")
def ai_translate(body: TranslateIn, user: dict = Depends(get_current_user)):
    translated = ai.translate_text(body.text, body.target_language)
    return {"translated": translated or body.text, "was_translated": translated is not None}


# =====================================================================
# Products
# =====================================================================
@app.get("/products")
def list_products(search: str = "", category: str = "", sort: str = "newest",
                  mine: bool = False, user: dict = Depends(get_current_user)):
    """Marketplace list. sort = newest | price_low | price_high | rating.
    mine=true returns the seller's own listings (all statuses)."""
    df = ds.load_products()
    if df.empty:
        return []
    if mine:
        require_role(user, "Seller")
        df = df[df["seller_id"] == user["user_id"]]
    else:
        df = df[df["status"] == "Active"]
    if category and category != "All":
        df = df[df["category"] == category]
    q = search.strip().lower()
    if q and not df.empty:
        hay = (df["product_name"].fillna("") + " " + df["category"].fillna("") + " "
               + df["material"].fillna("") + " " + df["english_desc"].fillna("")).str.lower()
        df = df[hay.str.contains(q, regex=False)]
    if df.empty:
        return []

    names, ratings = user_names(), ds.get_ratings_by_product()
    items = [product_out(r, names, ratings) for r in df.to_dict("records")]
    if sort == "price_low":
        items.sort(key=lambda p: p["price"])
    elif sort == "price_high":
        items.sort(key=lambda p: -p["price"])
    elif sort == "rating":
        items.sort(key=lambda p: (-p["avg_rating"], -p["review_count"]))
    else:
        items.sort(key=lambda p: p["created_at"] or "", reverse=True)
    return items


@app.get("/products/{product_id}")
def product_detail(product_id: str, user: dict = Depends(get_current_user)):
    row = ds.get_product(product_id)
    if row is None:
        raise HTTPException(404, "Product not found.")
    names, ratings = user_names(), ds.get_ratings_by_product()
    product = product_out(row, names, ratings)

    # Description in the viewer's own language
    code, lang_name = ai._resolve_language(user.get("language") or "")
    display_desc, display_lang = product["english_desc"] or "", "English"
    if lang_name == "Hindi" and product["hindi_desc"]:
        display_desc, display_lang = product["hindi_desc"], "Hindi"
    elif code and lang_name != "English":
        translated = ai.translate_text(product["english_desc"] or "", user.get("language"))
        if translated:
            display_desc, display_lang = translated, lang_name

    seller = ds.get_user(row["seller_id"])
    s_avg, s_cnt = ds.get_seller_rating(row["seller_id"])
    reviews = []
    rdf = ds.get_reviews_for_product(product_id)
    if not rdf.empty:
        for r in rdf.to_dict("records"):
            reviews.append(clean({
                "review_id": r["review_id"], "review_type": r["review_type"],
                "is_seller_initial": r["review_type"] == "seller_initial",
                "reviewer_name": names.get(r["buyer_id"] if r["review_type"] == "product" else r["seller_id"], ""),
                "rating": to_int(r["rating"]), "comment": r["comment"], "created_at": r["created_at"],
            }))
    return {
        "product": product, "display_desc": display_desc, "display_language": display_lang,
        "seller": {**(public_user(seller) if seller else {}),
                   "rating": {"average": s_avg, "count": s_cnt}},
        "reviews": reviews,
    }


@app.post("/products")
def create_product(
    product_name: str = Form(...), category: str = Form(...), material: str = Form(""),
    price: float = Form(...), stock: int = Form(...),
    english_desc: str = Form(""), hindi_desc: str = Form(""), language: str = Form(""),
    image: UploadFile = File(...), user: dict = Depends(get_current_user),
):
    require_role(user, "Seller")
    if price <= 0 or stock < 0:
        raise HTTPException(400, "Price must be above 0 and stock can't be negative.")
    if category not in ai.CATEGORIES:
        category = ai.FALLBACK_CATEGORY
    try:
        img = Image.open(io.BytesIO(image.file.read()))
        img.load()
    except Exception:
        raise HTTPException(400, "That file isn't a valid image.")
    pid = ds.save_product(
        seller_id=user["user_id"], product_name=product_name.strip(), category=category,
        material=material.strip(), price=int(round(price)), stock=stock,
        english_desc=english_desc.strip(), hindi_desc=hindi_desc.strip(),
        image=img, language=language.strip() or None)
    return {"product_id": pid}


class ProductUpdate(BaseModel):
    status: Optional[str] = None  # Active | Inactive
    stock: Optional[int] = Field(default=None, ge=0)


def _own_product(product_id: str, user: dict) -> dict:
    require_role(user, "Seller")
    row = ds.get_product(product_id)
    if row is None:
        raise HTTPException(404, "Product not found.")
    if row["seller_id"] != user["user_id"]:
        raise HTTPException(403, "That isn't your product.")
    return row


@app.put("/products/{product_id}")
def update_product(product_id: str, body: ProductUpdate, user: dict = Depends(get_current_user)):
    _own_product(product_id, user)
    if body.status is not None:
        if body.status not in ("Active", "Inactive"):
            raise HTTPException(400, "Status must be Active or Inactive.")
        ds.update_product_status(product_id, body.status)
    if body.stock is not None:
        ds.update_product_stock(product_id, body.stock)
    return {"ok": True}


@app.delete("/products/{product_id}")
def remove_product(product_id: str, user: dict = Depends(get_current_user)):
    _own_product(product_id, user)
    ds.delete_product(product_id)
    return {"ok": True}


# =====================================================================
# Orders
# =====================================================================
class OrderItem(BaseModel):
    product_id: str
    quantity: int = Field(ge=1)


class OrderIn(BaseModel):
    items: List[OrderItem] = Field(min_length=1)
    shipping_address: str = Field(min_length=5)
    payment_method: str


@app.post("/orders")
def create_orders(body: OrderIn, user: dict = Depends(get_current_user)):
    """Checkout. One order is created per cart item (like the Streamlit app)."""
    require_role(user, "Buyer")
    if body.payment_method not in config.PAYMENT_METHODS:
        raise HTTPException(400, "Choose Cash on Delivery, UPI or Card.")
    # Check everything first so a failed item doesn't leave a half-placed cart.
    for item in body.items:
        p = ds.get_product(item.product_id)
        if p is None or p["status"] != "Active":
            raise HTTPException(400, f"'{item.product_id}' is no longer available.")
        if p["seller_id"] == user["user_id"]:
            raise HTTPException(400, "You can't buy your own product.")
        if to_int(p["stock"]) < item.quantity:
            raise HTTPException(400, f"Only {to_int(p['stock'])} left of '{p['product_name']}'.")
    order_ids = []
    for item in body.items:
        oid = ds.place_order(user["user_id"], item.product_id, item.quantity,
                             body.shipping_address.strip(), body.payment_method)
        order_ids.append(oid)
    return {"order_ids": order_ids}


@app.get("/orders")
def list_orders(status: str = "", user: dict = Depends(get_current_user)):
    """Buyers see their own orders; sellers see incoming orders."""
    df = ds.load_orders()
    if df.empty:
        return []
    is_seller = user.get("role") == "Seller"
    df = df[df["seller_id" if is_seller else "buyer_id"] == user["user_id"]]
    if status:
        df = df[df["status"] == status]
    if df.empty:
        return []
    names = user_names()
    products = ds.load_products().set_index("product_id") if not ds.load_products().empty else None
    out = []
    for r in df.sort_values("created_at", ascending=False).to_dict("records"):
        img = None
        if products is not None and r["product_id"] in products.index:
            img = image_url(products.loc[r["product_id"], "image_path"])
        item = {
            **r, "quantity": to_int(r["quantity"]), "total_amount": to_int(r["total_amount"]),
            "image_url": img, "buyer_name": names.get(r["buyer_id"], ""),
            "seller_name": names.get(r["seller_id"], ""),
        }
        if is_seller:
            item["buyer_reviewed"] = ds.has_reviewed_order(r["order_id"], "buyer")
        else:
            item["product_reviewed"] = ds.has_reviewed_order(r["order_id"], "product")
            item["seller_reviewed"] = ds.has_reviewed_order(r["order_id"], "seller")
        out.append(clean(item))
    return out


class StatusIn(BaseModel):
    status: str


# Allowed moves. Sellers run the order; a buyer may cancel only a brand-new order.
_SELLER_MOVES = {"New": {"Processing", "Cancelled"}, "Processing": {"Completed", "Cancelled"}}
_BUYER_MOVES = {"New": {"Cancelled"}}


@app.put("/orders/{order_id}/status")
def set_order_status(order_id: str, body: StatusIn, user: dict = Depends(get_current_user)):
    order = ds.get_order(order_id)
    if order is None:
        raise HTTPException(404, "Order not found.")
    if user["user_id"] == order["seller_id"]:
        moves = _SELLER_MOVES
    elif user["user_id"] == order["buyer_id"]:
        moves = _BUYER_MOVES
    else:
        raise HTTPException(403, "That isn't your order.")
    if body.status not in moves.get(order["status"], set()):
        raise HTTPException(400, f"Can't change an order from {order['status']} to {body.status}.")
    ds.update_order_status(order_id, body.status)
    if body.status == "Cancelled":  # give the stock back
        p = ds.get_product(order["product_id"])
        if p is not None:
            ds.update_product_stock(order["product_id"], to_int(p["stock"]) + to_int(order["quantity"]))
    return {"ok": True, "status": body.status}


# =====================================================================
# Reviews
# =====================================================================
class ReviewIn(BaseModel):
    review_type: str  # product | seller | buyer | seller_initial
    rating: int = Field(ge=1, le=5)
    comment: str = ""
    order_id: Optional[str] = None
    product_id: Optional[str] = None


@app.post("/reviews")
def create_review(body: ReviewIn, user: dict = Depends(get_current_user)):
    t = body.review_type
    if t == "seller_initial":
        require_role(user, "Seller")
        if not body.product_id:
            raise HTTPException(400, "product_id is required.")
        _own_product(body.product_id, user)
        rid = ds.add_seller_initial_review(body.product_id, user["user_id"], body.rating, body.comment)
        if rid is None:
            raise HTTPException(409, "You've already added an opening review for this product.")
        return {"review_id": rid}

    if t not in ("product", "seller", "buyer"):
        raise HTTPException(400, "Unknown review type.")
    if not body.order_id:
        raise HTTPException(400, "order_id is required.")
    order = ds.get_order(body.order_id)
    if order is None:
        raise HTTPException(404, "Order not found.")
    if order["status"] != "Completed":
        raise HTTPException(400, "You can review only after the order is completed.")

    if t in ("product", "seller"):
        require_role(user, "Buyer")
        if order["buyer_id"] != user["user_id"]:
            raise HTTPException(403, "That isn't your order.")
        fn = ds.add_product_review if t == "product" else ds.add_seller_review
    else:
        require_role(user, "Seller")
        if order["seller_id"] != user["user_id"]:
            raise HTTPException(403, "That isn't your order.")
        fn = ds.add_buyer_review

    rid = fn(order["order_id"], order["product_id"], order["seller_id"],
             order["buyer_id"], body.rating, body.comment)
    if rid is None:
        raise HTTPException(409, "You've already submitted this review for the order.")
    return {"review_id": rid}


# =====================================================================
# Seller analytics
# =====================================================================
@app.get("/sellers/me/analytics")
def seller_analytics(date_from: Optional[str] = None, date_to: Optional[str] = None,
                     user: dict = Depends(get_current_user)):
    """Dates are YYYY-MM-DD. Earnings count COMPLETED orders only."""
    require_role(user, "Seller")
    uid = user["user_id"]
    s_avg, s_cnt = ds.get_seller_rating(uid)

    products = ds.load_products()
    mine = products[products["seller_id"] == uid] if not products.empty else products
    low_stock = []
    if not mine.empty:
        for r in mine.to_dict("records"):
            if r["status"] == "Active" and to_int(r["stock"]) <= config.LOW_STOCK_THRESHOLD:
                low_stock.append({"product_id": r["product_id"], "product_name": r["product_name"],
                                  "stock": to_int(r["stock"])})

    orders = ds.load_orders()
    orders = orders[orders["seller_id"] == uid].copy() if not orders.empty else orders
    empty = {"total_earnings": 0, "total_orders": 0, "completed_orders": 0, "pending_amount": 0}
    result = {"store_rating": {"average": s_avg, "count": s_cnt}, "low_stock": low_stock,
              "totals": empty, "earnings_by_date": [], "status_breakdown": {},
              "top_products": [], "revenue_by_category": []}
    if orders.empty:
        return clean(result)

    orders["when"] = pd.to_datetime(orders["created_at"], errors="coerce")
    orders["amount"] = pd.to_numeric(orders["total_amount"], errors="coerce").fillna(0)
    orders["qty"] = pd.to_numeric(orders["quantity"], errors="coerce").fillna(0)
    try:
        if date_from:
            orders = orders[orders["when"] >= pd.to_datetime(date_from)]
        if date_to:
            orders = orders[orders["when"] < pd.to_datetime(date_to) + pd.Timedelta(days=1)]
    except Exception:
        raise HTTPException(400, "Dates must look like 2026-10-01.")
    if orders.empty:
        return clean(result)

    done = orders[orders["status"] == "Completed"]
    live = orders[orders["status"] != "Cancelled"]
    pending = orders[orders["status"].isin(["New", "Processing"])]
    result["totals"] = {
        "total_earnings": to_int(done["amount"].sum()), "total_orders": int(len(orders)),
        "completed_orders": int(len(done)), "pending_amount": to_int(pending["amount"].sum()),
    }
    result["status_breakdown"] = {s: int((orders["status"] == s).sum()) for s in config.ORDER_STATUSES}
    if not done.empty:
        by_day = done.groupby(done["when"].dt.strftime("%Y-%m-%d"))["amount"].sum()
        result["earnings_by_date"] = [{"date": d, "amount": to_int(a)} for d, a in by_day.items()]
    if not live.empty:
        top = live.groupby("product_name").agg(units=("qty", "sum"), revenue=("amount", "sum"))
        top = top.sort_values("revenue", ascending=False).head(5)
        result["top_products"] = [{"product_name": n, "units": to_int(r["units"]),
                                   "revenue": to_int(r["revenue"])} for n, r in top.iterrows()]
    if not done.empty and not products.empty:
        cat = products.set_index("product_id")["category"].to_dict()
        d2 = done.assign(category=done["product_id"].map(cat).fillna("Other Handicraft"))
        by_cat = d2.groupby("category")["amount"].sum().sort_values(ascending=False)
        result["revenue_by_category"] = [{"category": c, "revenue": to_int(a)} for c, a in by_cat.items()]
    return clean(result)
