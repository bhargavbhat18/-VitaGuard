from fastapi import APIRouter, Depends, HTTPException
from app.models.vitals import VitalsReading, VitalsResponse
from app.database import get_db
from app.middleware.auth_guard import verify_firebase_token
from app.services.threshold import check_thresholds
from app.services.notifications import send_alert_notification
from app.services.sms_service import send_alert_sms
from app.routes.websocket import broadcast_vitals
from datetime import datetime, timezone
router = APIRouter()

@router.post("", response_model=VitalsResponse)
async def receive_vitals(reading: VitalsReading, uid: str = Depends(verify_firebase_token)):
    db = get_db()
    reading.user_id  = uid
    reading.timestamp= datetime.now(timezone.utc)
    spo2 = reading.get_spo2()
    temp = reading.temperature or 36.6
    doc  = {"user_id":reading.user_id,"heart_rate":reading.heart_rate,
            "spO2":spo2,"bp_systolic":reading.bp_systolic,
            "bp_diastolic":reading.bp_diastolic,"glucose":reading.glucose,
            "temperature":temp,"timestamp":reading.timestamp}
    alert, message = check_thresholds(reading)
    doc["alert_triggered"] = alert
    doc["alert_message"]   = message
    result = await db.vitals.insert_one(doc)
    await broadcast_vitals(uid, doc)
    if alert:
        user = await db.users.find_one({"uid":uid})
        patient_name   = user.get("full_name", "Patient") if user else "Patient"
        emergency_phone = user.get("emergency_contact_phone", "") if user else ""
        location = {"lat": 12.9716, "lng": 77.5946}  # default; use GPS from reading if available
        # Send SMS to hardcoded numbers + user's emergency contact (background, non-blocking)
        import asyncio
        asyncio.ensure_future(send_alert_sms(
            user_id=uid,
            patient_name=patient_name,
            alert_message=message,
            location=location,
            extra_numbers=[emergency_phone] if emergency_phone else [],
        ))
        if user and user.get("fcm_token"):
            await send_alert_notification(user["fcm_token"], message)
    return VitalsResponse(user_id=doc["user_id"],heart_rate=doc["heart_rate"],
        spO2=doc["spO2"],bp_systolic=doc["bp_systolic"],bp_diastolic=doc["bp_diastolic"],
        glucose=doc["glucose"],temperature=doc["temperature"],timestamp=doc["timestamp"],
        id=str(result.inserted_id),alert_triggered=alert,alert_message=message)

@router.get("/latest")
async def get_latest(uid: str = Depends(verify_firebase_token)):
    db = get_db()
    doc = await db.vitals.find_one({"user_id":uid},sort=[("timestamp",-1)],projection={"_id":0})
    if not doc: raise HTTPException(status_code=404,detail="No vitals found")
    return doc

@router.get("/history")
async def get_history(limit: int = 50, uid: str = Depends(verify_firebase_token)):
    db = get_db()
    cursor = db.vitals.find({"user_id":uid},sort=[("timestamp",-1)],limit=limit,projection={"_id":0})
    return await cursor.to_list(length=limit)
