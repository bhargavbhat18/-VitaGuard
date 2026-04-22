from fastapi import APIRouter, Depends, HTTPException
from app.database import get_db
from app.middleware.auth_guard import verify_firebase_token
from typing import List
from app.models.user import FamilyMember

router = APIRouter()

@router.get("/members", response_model=List[FamilyMember])
async def get_family_members(uid: str = Depends(verify_firebase_token)):
    db = get_db()
    user = await db.users.find_one({"uid": uid}, {"family_members": 1, "_id": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user.get("family_members", [])
