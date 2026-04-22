from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.database import get_db
from app.services.ambulance_service import get_all_ambulances, update_hospital_resources
from app.services.traffic_service import get_traffic_log, get_active_corridors
from typing import List
from datetime import datetime, timezone
import json
router = APIRouter()
_hospital_ws: List[WebSocket] = []

@router.get("/")
async def list_hospitals():
    db = get_db()
    # Return all hospitals with their embedded doctor lists
    cursor = db.hospitals.find({}, {"_id": 0})
    return await cursor.to_list(length=100)

async def notify_hospital(event: dict):
    dead=[]
    for ws in _hospital_ws:
        try:
            payload={k:(str(v) if hasattr(v,'isoformat') else v) for k,v in event.items()}
            await ws.send_text(json.dumps(payload))
        except: dead.append(ws)
    for ws in dead: _hospital_ws.remove(ws)

@router.get("/emergencies")
async def get_emergencies():
    db = get_db()
    cursor = db.sos_events.find({"status":{"$in":["triggered","ambulance_en_route"]}},
        sort=[("timestamp",-1)],limit=50)
    items = await cursor.to_list(length=50)
    for i in items:
        if "_id" in i: i["_id"] = str(i["_id"])
        if "hospital" in i and isinstance(i["hospital"], dict) and "_id" in i["hospital"]:
            i["hospital"]["_id"] = str(i["hospital"]["_id"])
    return items

@router.get("/ambulances")
async def hospital_ambulances(): return get_all_ambulances()

@router.get("/stats")
async def hospital_stats():
    db = get_db()
    cursor = db.hospitals.find({}, {"_id": 0})
    hospitals = await cursor.to_list(length=100)
    
    return {
        "total_sos": await db.sos_events.count_documents({}),
        "active":    await db.sos_events.count_documents({"status": "ambulance_en_route"}),
        "resolved":  await db.sos_events.count_documents({"status": "resolved"}),
        "total_patients": await db.users.count_documents({}),
        "hospitals": hospitals
    }

@router.get("/traffic/log")
async def traffic_log_hospital(): return get_traffic_log()

@router.get("/traffic/corridors")
async def corridors(): return get_active_corridors()

# ── Mark patient as cured / resolved ─────────────────────────
@router.post("/resolve/{sos_id}")
async def resolve_case(sos_id: str):
    """
    Hospital marks a patient as cured/discharged.
    Updates the SOS event status to 'resolved' and broadcasts
    to ALL connected hospital dashboards + mobile clients.
    """
    from bson import ObjectId
    db = get_db()
    # Support both string sos_id and ObjectId
    try:
        oid = ObjectId(sos_id)
        flt = {"_id": oid}
    except Exception:
        flt = {"sos_id": sos_id}

    # Find the event first to identify the hospital
    event = await db.sos_events.find_one(flt)
    
    result = await db.sos_events.update_one(
        flt,
        {"$set": {
            "status": "resolved",
            "resolved_at": datetime.now(timezone.utc).isoformat(),
            "patient_cured": True,
        }}
    )
    
    if event and event.get("hospital"):
        h_name = event["hospital"].get("name")
        if h_name:
            # Increment resources back
            await update_hospital_resources(h_name, 1, 1)
    if result.matched_count == 0:
        # Try user_id fallback
        await db.sos_events.update_many(
            {"user_id": sos_id, "status": {"$ne": "resolved"}},
            {"$set": {"status": "resolved", "patient_cured": True,
                      "resolved_at": datetime.now(timezone.utc).isoformat()}}
        )

    # Broadcast resolution to all hospital dashboard WebSocket connections
    await notify_hospital({
        "type": "case_resolved",
        "sos_id": sos_id,
        "message": f"Patient case {sos_id} marked as cured/discharged",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    return {"success": True, "sos_id": sos_id, "status": "resolved"}

@router.websocket("/ws")
async def hospital_ws(websocket: WebSocket):
    await websocket.accept()
    _hospital_ws.append(websocket)
    try:
        while True: await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in _hospital_ws: _hospital_ws.remove(websocket)
