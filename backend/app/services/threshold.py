from app.models.vitals import VitalsReading
from typing import Tuple

THRESHOLDS = {
    "heart_rate":   {"min": 50,   "max": 110},
    "spo2":         {"min": 92,   "max": 100},
    "bp_systolic":  {"min": 60,   "max": 140},
    "bp_diastolic": {"min": 40,   "max": 90},
    "glucose":      {"min": 70,   "max": 180},
    "temperature":  {"min": 35.0, "max": 37.5},  # °C
}

def check_thresholds(reading: VitalsReading) -> Tuple[bool, str]:
    alerts = []
    spo2   = reading.get_spo2()
    temp   = reading.temperature or 36.6

    hr = reading.heart_rate
    if hr < THRESHOLDS["heart_rate"]["min"]:
        alerts.append(f"Low heart rate: {hr} bpm")
    elif hr > THRESHOLDS["heart_rate"]["max"]:
        alerts.append(f"High heart rate: {hr} bpm")

    if spo2 < THRESHOLDS["spo2"]["min"]:
        alerts.append(f"Low SpO2: {spo2}%")

    if reading.bp_systolic > THRESHOLDS["bp_systolic"]["max"] or \
       reading.bp_diastolic > THRESHOLDS["bp_diastolic"]["max"]:
        alerts.append(f"High BP: {reading.bp_systolic}/{reading.bp_diastolic} mmHg")

    if reading.glucose > THRESHOLDS["glucose"]["max"]:
        alerts.append(f"High glucose: {reading.glucose} mg/dL")
    elif reading.glucose < THRESHOLDS["glucose"]["min"]:
        alerts.append(f"Low glucose: {reading.glucose} mg/dL")

    # Temperature checks
    if temp > THRESHOLDS["temperature"]["max"]:
        if temp >= 39.0:
            alerts.append(f"HIGH FEVER: {temp}°C — urgent")
        else:
            alerts.append(f"Elevated temperature: {temp}°C")
    elif temp < THRESHOLDS["temperature"]["min"]:
        alerts.append(f"Hypothermia risk: {temp}°C")

    return (True, " | ".join(alerts)) if alerts else (False, "")
