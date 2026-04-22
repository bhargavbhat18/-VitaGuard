import time, requests, os, random
from dotenv import load_dotenv
from vitals_generator import generate_vitals
from datetime import datetime

load_dotenv()

API_URL  = os.getenv("API_URL", "http://localhost:8000")
USER_ID  = os.getenv("USER_ID", "LKT01")
INTERVAL = int(os.getenv("INTERVAL", "10"))
HEADERS  = {"Authorization": f"Bearer {USER_ID}", "Content-Type": "application/json"}

EMERGENCY_TYPES = ["General", "Cardiology", "Trauma", "Pediatrics", "Oncology"]

def fetch_reg_location():
    """Fetch the registered location from the user profile for fallback testing"""
    try:
        r = requests.get(f"{API_URL}/auth/profile", headers=HEADERS, timeout=5)
        if r.status_code == 200:
            profile = r.json()
            return profile.get("location")
    except Exception as e:
        print(f"  [WARN] Could not fetch profile location: {e}")
    return None

def run():
    print(f"VitalGuard Intelligent Simulator started")
    print(f"  Target:     {API_URL}")
    print(f"  User ID:    {USER_ID}")
    
    reg_location = fetch_reg_location()
    if reg_location:
        addr = reg_location.get('address', 'Coordinates set')
        print(f"  Registered: {addr[:40]}...")
    else:
        print(f"  Registered: NO LOCATION SET (using system defaults)")

    print(f"  Matching:   Uber-inspired scoring enabled")
    print(f"  Interval:   {INTERVAL}s\n")
    
    cycle = 0
    while True:
        cycle += 1
        vitals = generate_vitals(simulate_emergency=(cycle % 5 == 0)) # More frequent for demo
        
        payload = {
            "user_id":      USER_ID,
            "heart_rate":   vitals["heart_rate"],
            "spO2":         vitals["spo2"],
            "bp_systolic":  vitals["bp_systolic"],
            "bp_diastolic": vitals["bp_diastolic"],
            "glucose":      vitals["glucose"],
            "temperature":  vitals["temperature"],
            "timestamp":    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        
        try:
            # 1. Send Vitals
            r = requests.post(f"{API_URL}/vitals", json=payload, headers=HEADERS, timeout=5)
            data = r.json()
            
            flag = "ALERT" if data.get("alert_triggered") else "OK"
            ts   = datetime.now().strftime("%H:%M:%S")
            print(f"[{ts}] [{flag}] HR:{payload['heart_rate']} SpO2:{payload['spO2']}% | BP:{payload['bp_systolic']}/{payload['bp_diastolic']}")
            
            if data.get("alert_triggered"):
                # 2. Trigger Intelligent SOS
                etype = random.choice(EMERGENCY_TYPES)
                # Simulate real-time GPS connectivity (70% success)
                # If False, backend should fall back to the registered home location
                has_gps = random.random() > 0.3
                
                source = "REAL-TIME GPS" if has_gps else "PROF-FALLBACK"
                print(f"         --> {etype.upper()} EMERGENCY! (LocSource: {source})")
                
                sos_payload = {
                    "alert_message": data.get("alert_message", "Vitals out of range"),
                    "emergency_type": etype,
                }
                
                if has_gps:
                    # Simulate a real-time location (slightly offset from home or city center)
                    base_lat = reg_location.get("lat", 12.9716) if reg_location else 12.9716
                    base_lng = reg_location.get("lng", 77.5946) if reg_location else 77.5946
                    sos_payload["location"] = {
                        "lat": base_lat + random.uniform(-0.0005, 0.0005),
                        "lng": base_lng + random.uniform(-0.0005, 0.0005)
                    }
                
                sos_r = requests.post(f"{API_URL}/sos/trigger", json=sos_payload, headers=HEADERS, timeout=5)
                sos_data = sos_r.json()
                h_name = sos_data.get('hospital', {}).get('name', 'Nearest Hospital')
                print(f"         --> DISPATCHED TO: {h_name}")
                
        except Exception as e:
            print(f"[ERROR] {e}")
            
        time.sleep(INTERVAL)

if __name__ == "__main__":
    run()
