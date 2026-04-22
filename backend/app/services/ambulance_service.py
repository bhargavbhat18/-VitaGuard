"""
Ambulance Service — VitalGuard
================================
Changes vs. v1:
  1. Hospital assignment is now LOAD-BALANCED — tracks active cases per
     hospital and routes new SOS to the hospital with fewest active cases.
     Breaks ties by geographic distance.
  2. Ambulance routing now follows real roads via the free OSRM routing API
     (router.project-osrm.org) instead of straight-line interpolation.
     Falls back to straight-line only if OSRM is unreachable.
"""

import asyncio, math, httpx
from typing import Dict, List, Optional
from datetime import datetime, timezone
from app.services.traffic_service import (
    request_green_corridor, update_ambulance_position, release_green_corridor)

from app.database import get_db

_ambulances: Dict[str, dict] = {}

# ── Intelligent Matching Logic ────────────────────────────────────

async def match_hospital(user_lat: float, user_lng: float, emergency_type: str = "General") -> dict:
    """
    Uber-like Intelligent Assignment:
    Scores hospitals based on Distance (40%), Specialization (40%), and Resources (20%).
    """
    db = get_db()
    cursor = db.hospitals.find({})
    hospitals = await cursor.to_list(length=100)
    
    if not hospitals:
        # Fallback to a default if DB is empty
        return {"name": "General Hospital", "lat": 12.9716, "lng": 77.5946}

    scored_hospitals = []
    # Max expected distance in city (e.g. 15km) for normalization
    MAX_DIST = 0.15 # Roughly in coordinate degrees for simplicity

    for h in hospitals:
        # 1. Distance Score (0-1)
        d = _dist(h, user_lat, user_lng)
        dist_score = max(0, 1 - (d / MAX_DIST)) if d < MAX_DIST else 0
        
        # 2. Specialization Score (0 or 1)
        spec_match = 1.0 if emergency_type in h.get("specializations", []) else 0.2
        if emergency_type == "General": spec_match = 1.0 # General matches everything
        
        # 3. Resource Availability Score (0-1)
        bed_ratio = h.get("available_beds", 0) / max(h.get("total_beds", 1), 1)
        doc_ratio = h.get("available_doctors", 0) / max(h.get("total_doctors", 1), 1)
        res_score = (bed_ratio + doc_ratio) / 2
        
        # 4. Active Case Penalty (calculated from live _ambulances)
        cases = _active_cases(h["name"])
        load_score = max(0, 1 - (cases / 10)) # Penalize if more than 10 cases

        # Weighted Total Score
        total_score = (dist_score * 0.4) + (spec_match * 0.4) + (res_score * 0.1) + (load_score * 0.1)
        
        # Hard filter: must have at least one bed
        if h.get("available_beds", 0) <= 0:
            total_score = -1
            
        scored_hospitals.append((h, total_score))
        print(f"[MATCH] {h['name']}: Score={total_score:.2f} (D={dist_score:.2f}, S={spec_match:.2f}, R={res_score:.2f}, L={load_score:.2f})")

    # Select best candidate
    best_h = max(scored_hospitals, key=lambda x: x[1])[0]
    # Convert ObjectId for JSON serialization
    if "_id" in best_h:
        best_h["_id"] = str(best_h["_id"])
    return best_h

async def update_hospital_resources(hospital_name: str, bed_delta: int, doctor_delta: int):
    """Atomically update available resources in DB."""
    db = get_db()
    await db.hospitals.update_one(
        {"name": hospital_name},
        {"$inc": {"available_beds": bed_delta, "available_doctors": doctor_delta}}
    )
    print(f"[HOSPITAL] {hospital_name} resources updated: Beds {bed_delta}, Docs {doctor_delta}")

def _dist(h: dict, lat: float, lng: float) -> float:
    """Euclidean distance (fine for short ranges in the same city)."""
    return math.sqrt((h["lat"] - lat) ** 2 + (h["lng"] - lng) ** 2)

def _active_cases(hospital_name: str) -> int:
    """Count currently active ambulances from this hospital."""
    return sum(
        1 for a in _ambulances.values()
        if a["hospital"] == hospital_name and a["status"] not in ("arrived", "cancelled")
    )

def nearest_hospital(user_lat: float, user_lng: float) -> dict:
    """Legacy wrapper for compatibility; uses the new matching logic with 'General' type."""
    # Since this is sync, and match_hospital is async, we have a problem.
    # However, the backend calls this from trigger_sos which is async.
    # I will refactor trigger_sos to call match_hospital directly.
    # For now, return a placeholder or raise if used synchronously.
    raise RuntimeError("Use async match_hospital instead of nearest_hospital")


# ── OSRM Road Routing ─────────────────────────────────────────────

async def _fetch_road_waypoints(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
    target_steps: int = 30,
) -> List[dict]:
    """
    Fetch real road-snapped waypoints from OSRM.
    Returns a list of {"lat": ..., "lng": ...} dicts.
    Falls back to straight-line on failure.
    """
    url = (
        f"http://router.project-osrm.org/route/v1/driving/"
        f"{from_lng},{from_lat};{to_lng},{to_lat}"
        f"?overview=full&geometries=geojson&steps=false"
    )
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(url)
            data = resp.json()
        route = data["routes"][0]
        coords = route["geometry"]["coordinates"]  # [[lng, lat], ...]
        dist = route["distance"]  # meters
        dur = route["duration"]  # seconds
        # Downsample/upsample to target_steps evenly spaced waypoints
        if len(coords) < 2:
            raise ValueError("Too few coords")
        pts = [{"lat": c[1], "lng": c[0]} for c in coords]
        return _resample(pts, target_steps), dist, dur
    except Exception as e:
        print(f"[OSRM] Routing failed ({e}), falling back to straight-line")
        pts = _straight_line_waypoints(from_lat, from_lng, to_lat, to_lng, target_steps)
        # Fallback estimation: 1.4x straight line distance, 40km/h speed
        d = math.sqrt((from_lat - to_lat)**2 + (from_lng - to_lng)**2) * 111000 * 1.4
        t = (d / 11.1)
        return pts, d, t


def _resample(pts: List[dict], n: int) -> List[dict]:
    """Evenly resample a polyline to exactly n waypoints."""
    if len(pts) >= n:
        idxs = [round(i * (len(pts) - 1) / (n - 1)) for i in range(n)]
        return [pts[i] for i in idxs]
    # Interpolate between existing points to fill
    result = []
    total_segs = n - 1
    seg_count = len(pts) - 1
    for i in range(n):
        t = i / total_segs * seg_count
        lo = min(int(t), seg_count - 1)
        hi = min(lo + 1, seg_count)
        frac = t - lo
        result.append({
            "lat": pts[lo]["lat"] + (pts[hi]["lat"] - pts[lo]["lat"]) * frac,
            "lng": pts[lo]["lng"] + (pts[hi]["lng"] - pts[lo]["lng"]) * frac,
        })
    return result


def _straight_line_waypoints(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
    n: int,
) -> List[dict]:
    return [
        {
            "lat": from_lat + (to_lat - from_lat) * i / (n - 1),
            "lng": from_lng + (to_lng - from_lng) * i / (n - 1),
        }
        for i in range(n)
    ]


# ── Ambulance Dispatch ────────────────────────────────────────────

async def dispatch_ambulance(
    sos_id: str,
    hospital: dict,
    user_lat: float,
    user_lng: float,
    total_steps: int = 30,
) -> None:
    # Decrement hospital resources on dispatch
    await update_hospital_resources(hospital["name"], -1, -1)
    
    # Fetch road-snapped waypoints from OSRM
    waypoints, dist, dur = await _fetch_road_waypoints(
        hospital["lat"], hospital["lng"],
        user_lat, user_lng,
        total_steps,
    )
    eta_min = round(dur / 60, 1)
    
    _ambulances[sos_id] = {
        "sos_id":           sos_id,
        "hospital":         hospital["name"],
        "status":           "dispatched",
        "step":             0,
        "total_steps":      total_steps,
        "current_lat":      hospital["lat"],
        "current_lng":      hospital["lng"],
        "destination_lat":  user_lat,
        "destination_lng":  user_lng,
        "eta_minutes":      eta_min,
        "total_distance":   dist,
        "total_duration":   dur,
        "progress":         0.0,
        "dispatched_at":    datetime.now(timezone.utc).isoformat(),
        "traffic_corridor": None,
        "route_type":       "road" if dist > 0 else "straight",
    }
    _ambulances[sos_id]["waypoints"] = [
        {"lat": w["lat"], "lng": w["lng"]} for w in waypoints
    ]

    # Request green corridor from traffic control
    corridor = await request_green_corridor(
        sos_id, hospital["name"],
        user_lat, user_lng,
        hospital["lat"], hospital["lng"],
        eta_min)
    _ambulances[sos_id]["traffic_corridor"] = corridor

    # Tracking loop
    db = get_db()
    from bson import ObjectId
    try:
        oid = ObjectId(sos_id)
        flt = {"_id": oid}
    except:
        flt = {"sos_id": sos_id}

    for step, wp in enumerate(waypoints, start=1):
        await asyncio.sleep(3)
        
        # Check if user has moved significantly
        event = await db.sos_events.find_one(flt)
        if event and "location" in event:
            new_u_lat = event["location"].get("lat", user_lat)
            new_u_lng = event["location"].get("lng", user_lng)
            
            # If user moved > 200m, re-calculate route (roughly 0.002 degrees)
            if abs(new_u_lat - user_lat) > 0.002 or abs(new_u_lng - user_lng) > 0.002:
                print(f"[AMBULANCE] Detected user movement! Re-routing {sos_id}...")
                user_lat, user_lng = new_u_lat, new_u_lng
                _ambulances[sos_id].update({
                    "destination_lat": user_lat,
                    "destination_lng": user_lng
                })
                # Re-fetch waypoints from current ambulance position to new user position
                curr_lat = _ambulances[sos_id]["current_lat"]
                curr_lng = _ambulances[sos_id]["current_lng"]
                remaining = total_steps - step
                if remaining > 0:
                    new_waypoints, new_dist, new_dur = await _fetch_road_waypoints(
                        curr_lat, curr_lng, user_lat, user_lng, remaining)
                    # Splice in the new waypoints
                    waypoints = waypoints[:step] + new_waypoints
                    # Update total distance/duration estimate (simplified)
                    _ambulances[sos_id]["total_distance"] = (_ambulances[sos_id].get("total_distance", 0) * (step / total_steps)) + new_dist
                    _ambulances[sos_id]["total_duration"] = (_ambulances[sos_id].get("total_duration", 0) * (step / total_steps)) + new_dur

        # Calculate progress, ETA, and distance remaining
        progress = step / len(waypoints)
        rem_dist = _calculate_remaining_dist(waypoints, step)
        eta = round((len(waypoints) - step) * 3 / 60, 1)
        
        status = "arrived" if step == len(waypoints) else "en_route"
        _ambulances[sos_id].update({
            "step":               step,
            "total_steps":        len(waypoints),
            "current_lat":        wp["lat"],
            "current_lng":        wp["lng"],
            "eta_minutes":        eta,
            "progress":           progress,
            "distance_remaining": rem_dist,
            "status":             status,
        })

        await update_ambulance_position(sos_id, wp["lat"], wp["lng"], eta, step)
        print(f"[AMBULANCE] {sos_id} step {step}/{len(waypoints)} "
              f"({wp['lat']:.5f},{wp['lng']:.5f}) ETA {eta} min")

    await release_green_corridor(sos_id)

def _calculate_remaining_dist(waypoints: List[dict], current_step: int) -> float:
    """Sum distances of remaining road segments in meters."""
    if current_step >= len(waypoints) - 1: return 0.0
    total = 0.0
    for i in range(current_step, len(waypoints) - 1):
        p1 = waypoints[i]
        p2 = waypoints[i+1]
        # Rough meters calculation (1 deg lat ~ 111km)
        dy = (p2["lat"] - p1["lat"]) * 111320
        dx = (p2["lng"] - p1["lng"]) * 111320 * math.cos(math.radians(p1["lat"]))
        total += math.sqrt(dx*dx + dy*dy)
    return round(total, 0)


async def get_ambulance_status(sos_id: str) -> Optional[dict]:
    amb = _ambulances.get(sos_id)
    if not amb: return None
    
    # Enrich with latest user location from DB
    from bson import ObjectId
    db = get_db()
    try:
        oid = ObjectId(sos_id)
        flt = {"_id": oid}
    except:
        flt = {"sos_id": sos_id}
    
    event = await db.sos_events.find_one(flt)
    if event and "location" in event:
        amb["user_location"] = event["location"]
    
    # DO NOT strip waypoints for specific status requests (needed for road-accurate polyline)
    return amb


def get_all_ambulances() -> List[dict]:
    # Strip the raw waypoints list from API responses (too large)
    result = []
    for a in _ambulances.values():
        copy = {k: v for k, v in a.items() if k != "waypoints"}
        result.append(copy)
    return result
