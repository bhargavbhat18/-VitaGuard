import requests

data = {
    "user_id":      "LKT01",
    "heart_rate":   135.0,
    "spO2":         87.0,
    "bp_systolic":  165.0,
    "bp_diastolic": 105.0,
    "glucose":      240.0,
    "temperature":  39.2,   # High fever
    "timestamp":    "2026-03-17 10:00:00",
}
print("Sending dangerous vitals...")
r = requests.post("http://localhost:8000/vitals",
    json=data, headers={"Authorization": "Bearer LKT01"})
print(r.json())
