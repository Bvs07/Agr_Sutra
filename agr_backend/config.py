"""Central settings. Values come from environment variables or a .env file."""
import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

SECRET_KEY = os.environ.get("AGR_SECRET_KEY", "dev-only-change-me")
TOKEN_EXPIRE_DAYS = 30
SIGNUP_TOKEN_MINUTES = 30
OTP_EXPIRE_SECONDS = 300
OTP_MAX_ATTEMPTS = 5

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
# If this model name stops working, change it here (or in .env). Nothing else needs editing.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
REMBG_MODEL = os.environ.get("REMBG_MODEL", "")

LOW_STOCK_THRESHOLD = 5
PAYMENT_METHODS = ["Cash on Delivery", "UPI", "Card"]
ORDER_STATUSES = ["New", "Processing", "Completed", "Cancelled"]
SIZES = ["Small", "Medium", "Large / Detailed"]
