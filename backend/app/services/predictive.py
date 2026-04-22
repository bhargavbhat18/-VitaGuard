import numpy as np
from typing import List, Dict
from datetime import datetime, timezone

def analyze_trends(readings: List[Dict]) -> Dict:
    if len(readings) < 3:
        return {"prediction":"insufficient_data","warning":False}
    hrs   = np.array([r.get("heart_rate",   75.0) for r in readings], dtype=float)
    spo2s = np.array([r.get("spO2",         98.0) for r in readings], dtype=float)
    bps   = np.array([r.get("bp_systolic", 120.0) for r in readings], dtype=float)
    glus  = np.array([r.get("glucose",     100.0) for r in readings], dtype=float)
    temps = np.array([r.get("temperature",  36.6) for r in readings], dtype=float)
    x     = np.arange(len(hrs), dtype=float)

    def slope(arr):
        return float(np.polyfit(x, arr, 1)[0]) if len(arr)>=2 else 0.0
    def pred(arr, s=3):
        return float(np.polyval(np.polyfit(x,arr,1), len(arr)-1+s)) if len(arr)>=2 else float(arr[-1])

    hr_s=slope(hrs); spo2_s=slope(spo2s); bp_s=slope(bps); temp_s=slope(temps)
    warnings=[]; risk=0.0

    if hr_s>0.5:   warnings.append(f"HR rising +{hr_s:.1f} bpm/reading"); risk+=hr_s*2
    if pred(hrs)>100: warnings.append(f"Predicted HR→{pred(hrs):.0f} bpm"); risk+=10
    if spo2_s<-0.1: warnings.append(f"SpO2 dropping -{abs(spo2_s):.2f}%/reading"); risk+=abs(spo2_s)*20
    if pred(spo2s)<94: warnings.append(f"Predicted SpO2→{pred(spo2s):.1f}%"); risk+=15
    if hr_s>0.3 and spo2_s<-0.08:
        warnings.append("CRITICAL PATTERN: HR↑ + SpO2↓ — respiratory distress risk"); risk+=30
    if bp_s>1.0: warnings.append(f"BP rising +{bp_s:.1f} mmHg/reading"); risk+=bp_s*1.5
    if temp_s>0.05: warnings.append(f"Temperature rising +{temp_s:.3f}°C/reading"); risk+=temp_s*20
    if pred(temps)>37.5: warnings.append(f"Predicted temp→{pred(temps):.1f}°C (fever)"); risk+=12

    level="critical" if risk>=40 else "warning" if risk>=20 else "caution" if risk>=8 else "normal"
    return {"prediction":level,"warning":risk>=20,"risk_score":round(risk,1),
            "warnings":warnings,"analyzed_at":datetime.now(timezone.utc).isoformat(),
            "readings_used":len(readings)}
