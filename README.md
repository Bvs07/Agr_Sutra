# AGR Sutra (Artisan Global Reach Sutra)

**AI-driven market linkage and smart cataloging app for artisans.**

Built as part of our team's Smart India Hackathon solution. AGR Sutra helps artisans list and sell their crafts without needing to write product descriptions or set prices by hand, and connects them directly with buyers.

## Features

### For sellers
- **AI camera studio**: take a product photo and get automatic photo cleanup
- **Voice input in 14 Indian languages**: describe your product by speaking
- **Auto-generated bilingual listings** (English and Hindi) with a suggested price, powered by Google Gemini
- **Earnings dashboard** to track sales
- **Order management** and two-way ratings

### For buyers
- Marketplace **search and browsing**
- **Cart and checkout**
- **Order tracking**
- Rate sellers and products

### Platform
- Separate **Seller** and **Buyer** interfaces in one app (multi-role)
- **JWT-based** login
- 15+ REST API endpoints

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter, Dart, Provider (state management) |
| Backend | Python, FastAPI |
| AI | Google Gemini API |
| Auth | JWT |
| Communication | REST APIs |

## Repository Structure

```
Agr_Sutra/
├── agr_backend/      # FastAPI backend (REST APIs, JWT auth, Gemini integration)
└── agr_sutra_app/    # Flutter Android app (Seller and Buyer interfaces)
```

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Python 3.9+
- A Google Gemini API key

### 1. Run the backend

```bash
cd agr_backend
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS / Linux
pip install -r requirements.txt
```

Create a `.env` file inside `agr_backend` with your secrets (this file is git-ignored and never uploaded):

```
GEMINI_API_KEY=your_key_here
SECRET_KEY=your_jwt_secret_here
```

Start the server:

```bash
uvicorn main:app --reload
```

API docs will be available at `http://127.0.0.1:8000/docs`.

### 2. Run the app

```bash
cd agr_sutra_app
flutter pub get
flutter run
```

If you run the app on a physical Android device, update the backend base URL in the app's configuration to your computer's local IP address (for example `http://192.168.x.x:8000`) and keep both on the same Wi-Fi network.

### 3. Build a release APK

```bash
cd agr_sutra_app
flutter build apk --release
```

## My Contribution

I developed the multi-role Flutter/Dart Android app, including the AI camera studio, marketplace search, cart, checkout, order tracking, ratings, and seller earnings dashboard. I integrated the app with the FastAPI backend, tested it on a physical Android device, and built the release APK. The project was built with AI-assisted development: I defined the features and API design, chose the tech stack, and reviewed and debugged the generated code.

## Acknowledgements

Developed for the Smart India Hackathon.
