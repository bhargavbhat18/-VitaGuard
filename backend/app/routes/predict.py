from fastapi import APIRouter, Depends, HTTPException
from app.middleware.auth_guard import verify_firebase_token
from app.database import get_db
from app.services.predictive import analyze_trends
router = APIRouter()

@router.get("/predict/{user_id}")
async def get_prediction(user_id: str, limit: int = 24, uid: str = Depends(verify_firebase_token)):
    db = get_db()
    cursor = db.vitals.find({"user_id":user_id},sort=[("timestamp",-1)],limit=limit,projection={"_id":0})
    readings = await cursor.to_list(length=limit)
    if not readings: raise HTTPException(status_code=404,detail="No vitals data found")
    readings.reverse()
    return analyze_trends(readings)
