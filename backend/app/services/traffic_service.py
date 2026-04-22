"""
Traffic Control System Integration
Problem Statement 2: Automated communication with traffic control systems
to optimize emergency response time and ensure timely medical intervention.

This service:
1. Notifies simulated traffic control center when ambulance is dispatched
2. Requests green corridor (all signals green) along ambulance route
3. Updates traffic control with ambulance ETA and current position
4. Logs all traffic system communications
"""
import asyncio
from datetime import datetime, timezone
from typing import Optional

# Simulated traffic signals along Bengaluru ambulance routes
TRAFFIC_SIGNALS = [
    {"id": "SIG-001", "name": "MG Road Junction",       "lat": 12.9758, "lng": 77.6069},
    {"id": "SIG-002", "name": "Brigade Road Cross",      "lat": 12.9699, "lng": 77.6010},
    {"id": "SIG-003", "name": "Residency Road Signal",   "lat": 12.9680, "lng": 77.5950},
    {"id": "SIG-004", "name": "Richmond Circle",         "lat": 12.9641, "lng": 77.5940},
    {"id": "SIG-005", "name": "Koramangala Junction",    "lat": 12.9352, "lng": 77.6245},
]

# Traffic control log
_traffic_log = []
_green_corridors = {}

async def request_green_corridor(
    sos_id: str,
    hospital_name: str,
    patient_lat: float,
    patient_lng: float,
    hospital_lat: float,
    hospital_lng: float,
    eta_minutes: float,
) -> dict:
    """
    Request all traffic signals on ambulance route to turn green.
    In production: POST to city traffic management API.
    Simulation: logs the request and marks signals as cleared.
    """
    timestamp = datetime.now(timezone.utc).isoformat()

    # Find signals near the route (simplified: within bounding box)
    lat_min = min(patient_lat, hospital_lat) - 0.02
    lat_max = max(patient_lat, hospital_lat) + 0.02
    lng_min = min(patient_lng, hospital_lng) - 0.02
    lng_max = max(patient_lng, hospital_lng) + 0.02

    signals_cleared = [
        s for s in TRAFFIC_SIGNALS
        if lat_min <= s["lat"] <= lat_max and lng_min <= s["lng"] <= lng_max
    ]

    corridor = {
        "sos_id":           sos_id,
        "status":           "GREEN_CORRIDOR_ACTIVE",
        "hospital":         hospital_name,
        "signals_cleared":  len(signals_cleared),
        "signal_ids":       [s["id"] for s in signals_cleared],
        "signal_names":     [s["name"] for s in signals_cleared],
        "eta_minutes":      eta_minutes,
        "requested_at":     timestamp,
        "expires_at":       f"{eta_minutes + 5:.0f} minutes from now",
        "message":          f"GREEN CORRIDOR ACTIVATED: {len(signals_cleared)} signals cleared for ambulance from {hospital_name}",
    }

    _green_corridors[sos_id] = corridor
    _traffic_log.append({
        "time":    timestamp,
        "type":    "GREEN_CORRIDOR_REQUEST",
        "sos_id":  sos_id,
        "details": corridor["message"],
    })

    print(f"\n🚦 [TRAFFIC CONTROL] {corridor['message']}")
    print(f"   Signals cleared: {', '.join(s['name'] for s in signals_cleared)}")
    print(f"   ETA to patient: {eta_minutes} minutes\n")

    return corridor

async def update_ambulance_position(
    sos_id: str,
    current_lat: float,
    current_lng: float,
    eta_minutes: float,
    step: int,
) -> None:
    """
    Send live ambulance position update to traffic control.
    Allows signals ahead to prepare green phase.
    """
    timestamp = datetime.now(timezone.utc).isoformat()
    msg = {
        "time":        timestamp,
        "type":        "POSITION_UPDATE",
        "sos_id":      sos_id,
        "lat":         current_lat,
        "lng":         current_lng,
        "eta_minutes": eta_minutes,
        "step":        step,
        "details":     f"Ambulance at ({current_lat:.4f}, {current_lng:.4f}) — ETA {eta_minutes} min",
    }
    _traffic_log.append(msg)
    if step % 5 == 0:  # Log every 5 steps to avoid spam
        print(f"🚦 [TRAFFIC] Position update: ETA {eta_minutes} min")

async def release_green_corridor(sos_id: str) -> None:
    """Release traffic signals when ambulance arrives."""
    timestamp = datetime.now(timezone.utc).isoformat()
    if sos_id in _green_corridors:
        _green_corridors[sos_id]["status"] = "RELEASED"
        _traffic_log.append({
            "time":    timestamp,
            "type":    "CORRIDOR_RELEASED",
            "sos_id":  sos_id,
            "details": "Green corridor released — signals returned to normal",
        })
        print(f"🚦 [TRAFFIC] Green corridor released for SOS {sos_id}")

def get_traffic_log() -> list:
    return list(reversed(_traffic_log))

def get_active_corridors() -> list:
    return [c for c in _green_corridors.values() if c.get("status") == "GREEN_CORRIDOR_ACTIVE"]
