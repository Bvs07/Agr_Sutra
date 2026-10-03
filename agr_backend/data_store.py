"""
data_store.py
--------------
CSV-backed storage (same as the Streamlit app). Every function keeps its
original name and arguments, so this file can later be swapped for a real
database (Postgres / Supabase / Firebase) without touching main.py.
"""
import os
import uuid
from datetime import datetime

import pandas as pd
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
IMAGES_DIR = os.path.join(DATA_DIR, "images")
USERS_PATH = os.path.join(DATA_DIR, "users.csv")
PRODUCTS_PATH = os.path.join(DATA_DIR, "products.csv")
ORDERS_PATH = os.path.join(DATA_DIR, "orders.csv")
REVIEWS_PATH = os.path.join(DATA_DIR, "reviews.csv")

USER_COLUMNS = [
    "user_id", "full_name", "phone", "email", "pin_code",
    "language", "role", "latitude", "longitude", "created_at",
]
PRODUCT_COLUMNS = [
    "product_id", "seller_id", "product_name", "category", "material",
    "language", "price", "stock", "english_desc", "hindi_desc",
    "image_path", "status", "created_at",
]
ORDER_COLUMNS = [
    "order_id", "buyer_id", "seller_id", "product_id", "product_name",
    "quantity", "total_amount", "shipping_address", "payment_method",
    "status", "created_at",
]
REVIEW_COLUMNS = [
    "review_id", "review_type", "order_id", "product_id", "seller_id",
    "buyer_id", "rating", "comment", "created_at",
]
VALID_REVIEW_TYPES = {"product", "seller", "buyer", "seller_initial"}

# Always load these as text so pandas never turns phone numbers / PIN codes / IDs into numbers.
_STRING_COLUMNS = {
    "user_id", "phone", "email", "pin_code",
    "product_id", "seller_id", "buyer_id", "order_id", "review_id",
}

os.makedirs(IMAGES_DIR, exist_ok=True)


def _ensure_csv(path: str, columns: list):
    if not os.path.exists(path):
        pd.DataFrame(columns=columns).to_csv(path, index=False)


def _load(path: str, columns: list) -> pd.DataFrame:
    _ensure_csv(path, columns)
    try:
        dtype_overrides = {col: str for col in columns if col in _STRING_COLUMNS}
        df = pd.read_csv(path, dtype=dtype_overrides, keep_default_na=True)
        for col in columns:
            if col not in df.columns:
                df[col] = pd.NA
        return df
    except Exception:
        return pd.DataFrame(columns=columns)


def _save(df: pd.DataFrame, path: str):
    df.to_csv(path, index=False)


# =====================================================================
# USERS
# =====================================================================
def load_users() -> pd.DataFrame:
    return _load(USERS_PATH, USER_COLUMNS)


def get_user_by_contact(phone: str = "", email: str = ""):
    df = load_users()
    if df.empty:
        return None
    match = pd.DataFrame()
    if phone:
        match = df[df["phone"].astype(str) == str(phone)]
    if match.empty and email:
        match = df[df["email"].astype(str).str.lower() == str(email).lower()]
    if match.empty:
        return None
    return match.iloc[-1].to_dict()


def get_user(user_id: str):
    df = load_users()
    if df.empty:
        return None
    match = df[df["user_id"] == user_id]
    return None if match.empty else match.iloc[0].to_dict()


def create_or_update_user(full_name, phone, email, pin_code, language, role) -> dict:
    df = load_users()
    existing = get_user_by_contact(phone=phone, email=email)
    if existing:
        idx = df[df["user_id"] == existing["user_id"]].index
        df.loc[idx, ["full_name", "phone", "email", "pin_code", "language", "role"]] = [
            full_name, phone, email, pin_code, language, role,
        ]
        _save(df, USERS_PATH)
        return df.loc[idx[0]].to_dict()

    user_id = str(uuid.uuid4())[:8]
    new_row = {
        "user_id": user_id, "full_name": full_name, "phone": phone,
        "email": email, "pin_code": pin_code, "language": language,
        "role": role, "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
    _save(df, USERS_PATH)
    return new_row


def update_user_profile(user_id: str, **fields):
    df = load_users()
    idx = df[df["user_id"] == user_id].index
    if idx.empty:
        return None
    for key, value in fields.items():
        if key in df.columns:
            if key in ("latitude", "longitude"):
                df[key] = df[key].astype(object)
            df.loc[idx, key] = value
    _save(df, USERS_PATH)
    return df.loc[idx[0]].to_dict()


# =====================================================================
# PRODUCTS
# =====================================================================
def load_products() -> pd.DataFrame:
    return _load(PRODUCTS_PATH, PRODUCT_COLUMNS)


def save_product(seller_id, product_name, category, material, price, stock,
                 english_desc, hindi_desc, image: Image.Image, language=None) -> str:
    df = load_products()
    product_id = str(uuid.uuid4())[:8]

    image_path = os.path.join(IMAGES_DIR, f"{product_id}.png")
    try:
        image.save(image_path, format="PNG")
    except Exception:
        image_path = ""

    new_row = {
        "product_id": product_id, "seller_id": seller_id, "product_name": product_name,
        "category": category, "material": material,
        "language": language or "Not detected", "price": price, "stock": stock,
        "english_desc": english_desc, "hindi_desc": hindi_desc,
        "image_path": image_path, "status": "Active",
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
    _save(df, PRODUCTS_PATH)
    return product_id


def get_product(product_id: str):
    df = load_products()
    match = df[df["product_id"] == product_id]
    return None if match.empty else match.iloc[0].to_dict()


def update_product_status(product_id: str, status: str):
    df = load_products()
    df.loc[df["product_id"] == product_id, "status"] = status
    _save(df, PRODUCTS_PATH)


def update_product_stock(product_id: str, new_stock: int):
    df = load_products()
    df.loc[df["product_id"] == product_id, "stock"] = new_stock
    _save(df, PRODUCTS_PATH)


def delete_product(product_id: str):
    df = load_products()
    row = df[df["product_id"] == product_id]
    if not row.empty:
        img_path = row.iloc[0].get("image_path")
        if isinstance(img_path, str) and img_path and os.path.exists(img_path):
            try:
                os.remove(img_path)
            except OSError:
                pass
    df = df[df["product_id"] != product_id]
    _save(df, PRODUCTS_PATH)


# =====================================================================
# ORDERS
# =====================================================================
def load_orders() -> pd.DataFrame:
    return _load(ORDERS_PATH, ORDER_COLUMNS)


def place_order(buyer_id, product_id, quantity, shipping_address, payment_method):
    product = get_product(product_id)
    if product is None:
        return None

    order_id = str(uuid.uuid4())[:8].upper()
    total_amount = int(float(product["price"])) * int(quantity)

    new_row = {
        "order_id": order_id, "buyer_id": buyer_id, "seller_id": product["seller_id"],
        "product_id": product_id, "product_name": product["product_name"],
        "quantity": quantity, "total_amount": total_amount,
        "shipping_address": shipping_address, "payment_method": payment_method,
        "status": "New", "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    df = load_orders()
    df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
    _save(df, ORDERS_PATH)

    products_df = load_products()
    idx = products_df[products_df["product_id"] == product_id].index
    if not idx.empty:
        current_stock = int(float(products_df.loc[idx[0], "stock"]))
        products_df.loc[idx[0], "stock"] = max(0, current_stock - int(quantity))
        _save(products_df, PRODUCTS_PATH)

    return order_id


def get_order(order_id: str):
    df = load_orders()
    match = df[df["order_id"] == order_id]
    return None if match.empty else match.iloc[0].to_dict()


def update_order_status(order_id: str, status: str):
    df = load_orders()
    df.loc[df["order_id"] == order_id, "status"] = status
    _save(df, ORDERS_PATH)


# =====================================================================
# REVIEWS & RATINGS
# =====================================================================
def load_reviews() -> pd.DataFrame:
    df = _load(REVIEWS_PATH, REVIEW_COLUMNS)
    if not df.empty:
        df["review_type"] = df["review_type"].fillna("product")
        df.loc[~df["review_type"].isin(VALID_REVIEW_TYPES), "review_type"] = "product"
    return df


def _add_review(review_type: str, rating: int, comment: str = "", order_id: str = "",
                product_id: str = "", seller_id: str = "", buyer_id: str = "") -> str:
    review_id = str(uuid.uuid4())[:8]
    new_row = {
        "review_id": review_id, "review_type": review_type, "order_id": order_id or "",
        "product_id": product_id or "", "seller_id": seller_id or "", "buyer_id": buyer_id or "",
        "rating": max(1, min(5, int(rating))), "comment": (comment or "").strip(),
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    df = load_reviews()
    df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
    _save(df, REVIEWS_PATH)
    return review_id


def has_reviewed_order(order_id: str, review_type: str = "product") -> bool:
    df = load_reviews()
    if df.empty:
        return False
    return not df[(df["order_id"] == order_id) & (df["review_type"] == review_type)].empty


def get_reviewable_product_orders(buyer_id: str, product_id: str):
    orders = load_orders()
    if orders.empty:
        return []
    candidates = orders[
        (orders["buyer_id"] == buyer_id)
        & (orders["product_id"] == product_id)
        & (orders["status"] == "Completed")
    ]
    if candidates.empty:
        return []
    reviews = load_reviews()
    reviewed_ids = set(reviews[reviews["review_type"] == "product"]["order_id"]) if not reviews.empty else set()
    pending = candidates[~candidates["order_id"].isin(reviewed_ids)]
    return pending.sort_values("created_at", ascending=False).to_dict("records")


def add_product_review(order_id, product_id, seller_id, buyer_id, rating, comment):
    if has_reviewed_order(order_id, "product"):
        return None
    return _add_review("product", rating, comment, order_id=order_id,
                       product_id=product_id, seller_id=seller_id, buyer_id=buyer_id)


def get_reviewable_seller_orders(buyer_id: str, seller_id: str):
    orders = load_orders()
    if orders.empty:
        return []
    candidates = orders[
        (orders["buyer_id"] == buyer_id)
        & (orders["seller_id"] == seller_id)
        & (orders["status"] == "Completed")
    ]
    if candidates.empty:
        return []
    reviews = load_reviews()
    reviewed_ids = set(reviews[reviews["review_type"] == "seller"]["order_id"]) if not reviews.empty else set()
    pending = candidates[~candidates["order_id"].isin(reviewed_ids)]
    return pending.sort_values("created_at", ascending=False).to_dict("records")


def add_seller_review(order_id, product_id, seller_id, buyer_id, rating, comment):
    if has_reviewed_order(order_id, "seller"):
        return None
    return _add_review("seller", rating, comment, order_id=order_id,
                       product_id=product_id, seller_id=seller_id, buyer_id=buyer_id)


def get_reviewable_buyer_order(order_id: str) -> bool:
    return not has_reviewed_order(order_id, "buyer")


def add_buyer_review(order_id, product_id, seller_id, buyer_id, rating, comment):
    if has_reviewed_order(order_id, "buyer"):
        return None
    return _add_review("buyer", rating, comment, order_id=order_id,
                       product_id=product_id, seller_id=seller_id, buyer_id=buyer_id)


def has_seller_reviewed_product(product_id: str) -> bool:
    df = load_reviews()
    if df.empty:
        return False
    return not df[(df["product_id"] == product_id) & (df["review_type"] == "seller_initial")].empty


def add_seller_initial_review(product_id, seller_id, rating, comment):
    if has_seller_reviewed_product(product_id):
        return None
    return _add_review("seller_initial", rating, comment, product_id=product_id, seller_id=seller_id)


def _mean_rating(subset: pd.DataFrame):
    if subset.empty:
        return 0.0, 0
    ratings = pd.to_numeric(subset["rating"], errors="coerce").dropna()
    if ratings.empty:
        return 0.0, 0
    return round(float(ratings.mean()), 1), int(len(ratings))


def get_product_rating(product_id: str):
    """Buyer product reviews only. The seller's own initial review is excluded."""
    df = load_reviews()
    if df.empty:
        return 0.0, 0
    return _mean_rating(df[(df["product_id"] == product_id) & (df["review_type"] == "product")])


def get_ratings_by_product() -> pd.DataFrame:
    df = load_reviews()
    if df.empty:
        return pd.DataFrame(columns=["avg_rating", "review_count"])
    subset = df[df["review_type"] == "product"].copy()
    if subset.empty:
        return pd.DataFrame(columns=["avg_rating", "review_count"])
    subset["rating"] = pd.to_numeric(subset["rating"], errors="coerce")
    grouped = subset.groupby("product_id")["rating"].agg(["mean", "count"])
    grouped = grouped.rename(columns={"mean": "avg_rating", "count": "review_count"})
    grouped["avg_rating"] = grouped["avg_rating"].round(1)
    return grouped


def get_reviews_for_product(product_id: str) -> pd.DataFrame:
    df = load_reviews()
    if df.empty:
        return df
    subset = df[(df["product_id"] == product_id)
                & (df["review_type"].isin(["product", "seller_initial"]))].copy()
    if subset.empty:
        return subset
    subset["created_at"] = pd.to_datetime(subset["created_at"], errors="coerce")
    return subset.sort_values("created_at", ascending=False)


def get_seller_rating(seller_id: str):
    df = load_reviews()
    if df.empty:
        return 0.0, 0
    return _mean_rating(df[(df["seller_id"] == seller_id) & (df["review_type"] == "seller")])


def get_buyer_rating(buyer_id: str):
    df = load_reviews()
    if df.empty:
        return 0.0, 0
    return _mean_rating(df[(df["buyer_id"] == buyer_id) & (df["review_type"] == "buyer")])
