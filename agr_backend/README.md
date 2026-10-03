# AGR Sutra Backend (FastAPI)

The Flutter app talks to this server. It holds the AI features and the Gemini key.

## 1. Setup (Windows, PowerShell)

```
cd C:\Users\DELL\projects\agr_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Open `.env` and fill in:
- `GEMINI_API_KEY` : your key from Google AI Studio (optional, there are offline fallbacks)
- `AGR_SECRET_KEY` : any long random text (used to sign login tokens)

Install **ffmpeg** (needed to convert voice recordings): `winget install Gyan.FFmpeg`, then reopen PowerShell.

## 2. Run

```
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Open http://localhost:8000/docs. This page lets you try every endpoint.
Quick check: http://localhost:8000/health should show `{"status":"ok", ...}`.

## 3. Which address does the Flutter app use?

| Where the app runs | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| Chrome (flutter run -d chrome) | `http://localhost:8000` |
| Real phone on the same Wi-Fi | `http://<your PC's IP>:8000` (find it with `ipconfig`; allow Python through Windows Firewall) |

## 4. Endpoints

| Area | Endpoints |
|---|---|
| Info | `GET /health`, `GET /meta` |
| Login | `POST /auth/send-otp`, `POST /auth/verify-otp`, `POST /auth/register` |
| Profile | `GET /users/me`, `PUT /users/me` |
| AI | `POST /ai/remove-background`, `/ai/transcribe`, `/ai/catalog-copy`, `/ai/suggest-price`, `/ai/translate` |
| Products | `GET /products` (search, category, sort, mine), `GET /products/{id}`, `POST /products`, `PUT /products/{id}`, `DELETE /products/{id}` |
| Orders | `POST /orders`, `GET /orders`, `PUT /orders/{id}/status` |
| Reviews | `POST /reviews` |
| Seller | `GET /sellers/me/analytics` |

All endpoints except `/health`, `/meta` and `/auth/*` need the header `Authorization: Bearer <access_token>`.
Product images are served from `/images/<file>.png`.

## 5. Notes

- Data is still stored in CSV files in the `data/` folder (created automatically). To move to a real database later, change only `data_store.py`.
- OTP is demo mode: the code is returned in the response and no SMS/email is sent. Before a real release, connect an SMS/email provider and remove `demo_otp` from `/auth/send-otp`.
- OTPs live in memory, so restarting the server clears pending OTPs (logins stay valid).
- If Gemini calls fail with a "model not found" error, change `GEMINI_MODEL` in `.env`.
- Recording voice in the app: use WAV format for best results.
