from fastapi import APIRouter, Depends, HTTPException
from app.models.user import UserProfile, UserProfileUpdate
from app.database import get_db
from app.middleware.auth_guard import verify_firebase_token
router = APIRouter()

@router.post("/profile")
async def create_or_update_profile(profile: UserProfile, uid: str = Depends(verify_firebase_token)):
    db = get_db()
    profile.uid = uid
    await db.users.update_one({"uid":uid},{"$set":profile.model_dump()},upsert=True)
    return {"message":"Profile saved","uid":uid}

@router.get("/profile")
async def get_profile(uid: str = Depends(verify_firebase_token)):
    db = get_db()
    user = await db.users.find_one({"uid":uid},{"_id":0})
    if not user: raise HTTPException(status_code=404,detail="Profile not found")
    return user

@router.patch("/profile")
async def update_profile(updates: UserProfileUpdate, uid: str = Depends(verify_firebase_token)):
    db = get_db()
    data = {k:v for k,v in updates.model_dump().items() if v is not None}
    await db.users.update_one({"uid":uid},{"$set":data})
    return {"message":"Profile updated"}
