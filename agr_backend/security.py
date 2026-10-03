"""Login tokens (JWT) and the 'who is calling?' dependency used by every protected endpoint."""
import time

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import config
from data_store import get_user

_bearer = HTTPBearer(auto_error=False)
_ALGO = "HS256"


def create_access_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "typ": "access",
        "exp": int(time.time()) + config.TOKEN_EXPIRE_DAYS * 86400,
    }
    return jwt.encode(payload, config.SECRET_KEY, algorithm=_ALGO)


def create_signup_token(phone: str = "", email: str = "") -> str:
    """Issued after a correct OTP for a brand-new user. Lets them finish registration."""
    payload = {
        "typ": "signup",
        "phone": phone,
        "email": email,
        "exp": int(time.time()) + config.SIGNUP_TOKEN_MINUTES * 60,
    }
    return jwt.encode(payload, config.SECRET_KEY, algorithm=_ALGO)


def decode_token(token: str, expected_type: str) -> dict:
    try:
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[_ALGO])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Session expired. Please log in again.")
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid token.")
    if payload.get("typ") != expected_type:
        raise HTTPException(401, "Invalid token type.")
    return payload


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(_bearer)) -> dict:
    if creds is None:
        raise HTTPException(401, "Please log in.")
    payload = decode_token(creds.credentials, "access")
    user = get_user(payload["sub"])
    if user is None:
        raise HTTPException(401, "User not found.")
    return user


def require_role(user: dict, role: str):
    if user.get("role") != role:
        raise HTTPException(403, f"This action is only available to {role}s.")
