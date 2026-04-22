from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import connect_db, close_db
from app.routes import auth, vitals, websocket, sos, predict, hospital, family, telehealth
from app.services.firebase_admin import init_firebase
import os

app = FastAPI(title="VitalGuard API — Phase 1 + Phase 2", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
async def startup():
    await connect_db()
    from app.config import DEV_MODE
    if not DEV_MODE:
        init_firebase()
    else:
        print("DEV_MODE=true — Firebase skipped")

@app.on_event("shutdown")
async def shutdown(): await close_db()

app.include_router(auth.router,      prefix="/auth",     tags=["Auth"])
app.include_router(vitals.router,    prefix="/vitals",   tags=["Vitals"])
app.include_router(websocket.router, tags=["WebSocket"])
app.include_router(sos.router,       prefix="/sos",      tags=["SOS + Traffic"])
app.include_router(predict.router,   prefix="/analysis", tags=["ML Prediction"])
app.include_router(hospital.router,  prefix="/hospital", tags=["Hospital Portal"])
app.include_router(family.router,    prefix="/family",   tags=["Family Circle"])
app.include_router(telehealth.router, tags=["Telehealth"])


@app.get("/")
async def root():
    return {"status":"VitalGuard running","version":"2.0.0",
            "features":["vitals+temperature","threshold_alerts","ml_prediction",
                        "sos_countdown","twilio_sms","ambulance_tracking",
                        "traffic_control","hospital_portal"]}
