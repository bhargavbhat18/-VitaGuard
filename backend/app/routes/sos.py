from fastapi import APIRouter, Depends, BackgroundTasks
from app.middleware.auth_guard import verify_firebase_token
from app.database import get_db
from app.services.sms_service import send_sos_sms, send_family_alert
from app.services.ambulance_service import (
    dispatch_ambulance, get_ambulance_status, get_all_ambulances, match_hospital)
from app.services.traffic_service import get_traffic_log, get_active_corridors
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone
router = APIRouter()

class SosRequest(BaseModel):
    alert_message: str
    location: Optional[dict] = None
    emergency_type: Optional[str] = "General"

class UserLocationUpdate(BaseModel):
    lat: float
    lng: float

@router.post("/user-location/{sos_id}")
async def update_user_location(sos_id: str, req: UserLocationUpdate):
    """Update user's live location during an active SOS."""
    from bson import ObjectId
    db = get_db()
    try:
        oid = ObjectId(sos_id)
        flt = {"_id": oid}
    except:
        flt = {"sos_id": sos_id}
    
    await db.sos_events.update_one(flt, {"$set": {"location": {"lat": req.lat, "lng": req.lng}}})
    return {"success": True}

@router.get("/patient-location/{uid}")
async def get_patient_location(uid: str):
    """
    Fetch patient's latest location. 
    Returns live location if an active SOS event exists, 
    otherwise falls back to registered home address.
    """
    db = get_db()
    
    # 1. Check for active SOS (live tracking)
    active_sos = await db.sos_events.find_one(
        {"user_id": uid, "status": {"$in": ["triggered", "ambulance_en_route"]}},
        sort=[("timestamp", -1)]
    )
    
    if active_sos and "location" in active_sos:
        return {
            "uid": uid,
            "lat": active_sos["location"].get("lat"),
            "lng": active_sos["location"].get("lng"),
            "address": active_sos.get("address") or "Emergency — Live Tracking",
            "is_live": True,
            "status": active_sos.get("status")
        }
    
    # 2. Fallback to registered home location in Profile
    user = await db.users.find_one({"uid": uid})
    if user and user.get("location"):
        loc = user["location"]
        return {
            "uid": uid,
            "lat": loc.get("lat"),
            "lng": loc.get("lng"),
            "address": loc.get("address", "Registered Home"),
            "is_live": False,
            "status": "normal"
        }
    
    # 3. Absolute fallback
    return {
        "uid": uid,
        "lat": 12.9716,
        "lng": 77.5946,
        "address": "Unknown — Fallback to City Center",
        "is_live": False,
        "status": "offline"
    }

@router.post("/trigger")
async def trigger_sos(req: SosRequest, bg: BackgroundTasks, uid: str = Depends(verify_firebase_token)):
    db   = get_db()
    user = await db.users.find_one({"uid":uid})
    
    # Prioritize real-time GPS, fallback to registered home address coordinates
    lat = req.location.get("lat") if req.location else None
    lng = req.location.get("lng") if req.location else None
    
    if lat is None or lng is None:
        if user and user.get("location") and "lat" in user["location"]:
            lat = user["location"]["lat"]
            lng = user["location"]["lng"]
        else:
            # Absolute fallback to city center
            lat, lng = 12.9716, 77.5946
            
    location = {"lat":lat,"lng":lng}
    
    # Use the new intelligent matching engine
    hospital = await match_hospital(lat, lng, req.emergency_type)
    
    sos_event = {
        "user_id": uid,
        "alert_message": req.alert_message,
        "location": location,
        "emergency_type": req.emergency_type,
        "hospital": hospital,
        "status": "triggered",
        "timestamp": datetime.now(timezone.utc),
        "cancelled": False,
        "sms_sent": False,
        "ambulance_dispatched": False
    }
    result = await db.sos_events.insert_one(sos_event)
    sos_id = str(result.inserted_id)
    patient_name = user.get("full_name","Patient") if user else "Patient"
    
    # Alert all registered family members
    family_members = user.get("family_members", []) if user else []
    
    async def do_all():
        # Also alert the primary emergency contact if set
        primary_phone = user.get("emergency_contact_phone","") if user else ""
        primary_name  = user.get("emergency_contact_name","") if user else ""
        
        if primary_phone:
            await send_sos_sms(primary_phone, patient_name, req.alert_message, location)
            await send_family_alert(primary_phone, primary_name, patient_name, req.alert_message, location)
        
        # Alert all other family members
        for member in family_members:
            m_phone = member.get("phone")
            m_name  = member.get("name")
            if m_phone and m_phone != primary_phone:
                await send_sos_sms(m_phone, patient_name, req.alert_message, location)
                await send_family_alert(m_phone, m_name, patient_name, req.alert_message, location)

        await db.sos_events.update_one({"_id":result.inserted_id},{"$set":{"sms_sent":True}})
        await dispatch_ambulance(sos_id, hospital, lat, lng)
        await db.sos_events.update_one({"_id":result.inserted_id},
            {"$set":{"ambulance_dispatched":True,"status":"ambulance_en_route"}})

    bg.add_task(do_all)
    return {"sos_id":sos_id, "status":"triggered", "hospital":hospital, "location":location, "emergency_type":req.emergency_type}

@router.get("/ambulance/{sos_id}")
async def ambulance_status(sos_id: str):
    status = get_ambulance_status(sos_id)
    return status or {"status":"not_found"}

@router.get("/ambulances")
async def all_ambulances(): return get_all_ambulances()

@router.get("/traffic/log")
async def traffic_log(): return get_traffic_log()

@router.get("/traffic/corridors")
async def active_corridors(): return get_active_corridors()

@router.get("/history")
async def sos_history(uid: str = Depends(verify_firebase_token)):
    db = get_db()
    cursor = db.sos_events.find({"user_id":uid},sort=[("timestamp",-1)],limit=20,projection={"_id":0})
    return await cursor.to_list(length=20)

class SmsTestRequest(BaseModel):
    to_phone: str  # e.g. "+919876543210"
    message: Optional[str] = "VitalGuard SMS test — your integration is working!"

@router.post("/test-sms")
async def test_sms(req: SmsTestRequest):
    """
    Test endpoint — send a real SMS to verify Twilio credentials.
    Call: POST /sos/test-sms  body: {"to_phone": "+919876543210"}
    No auth required so you can test from curl/Postman easily.
    """
    import os
    from twilio.rest import Client
    sid   = os.getenv("TWILIO_ACCOUNT_SID", "")
    token = os.getenv("TWILIO_AUTH_TOKEN", "")
    frm   = os.getenv("TWILIO_PHONE_FROM", "")
    if not (sid and token and frm) or sid == "your_account_sid_here":
        # Simulation mode — no credentials set yet
        print(f"\n[SMS TEST - SIMULATION]\nTo: {req.to_phone}\nMsg: {req.message}\n")
        return {"sent": True, "mode": "simulation",
                "note": "Set TWILIO_* env vars to send real SMS"}
    try:
        msg = Client(sid, token).messages.create(
            body=req.message, from_=frm, to=req.to_phone)
        return {"sent": True, "mode": "live", "sid": msg.sid, "status": msg.status}
    except Exception as e:
        return {"sent": False, "error": str(e)}
