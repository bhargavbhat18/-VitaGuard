from fastapi import HTTPException, Header
from typing import Optional
from app.config import DEV_MODE
async def verify_firebase_token(authorization: Optional[str] = Header(None)) -> str:
    if DEV_MODE:
        if authorization and authorization.startswith("Bearer "):
            token = authorization.split("Bearer ")[1]
            if token not in ["dev_token","anything","test"]:
                return token
        return "LKT01"
    from firebase_admin import auth as fa
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    try:
        return fa.verify_id_token(authorization.split("Bearer ")[1])["uid"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
