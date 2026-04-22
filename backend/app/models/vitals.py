from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class VitalsReading(BaseModel):
    user_id:      str
    heart_rate:   float
    spO2:         Optional[float] = None
    spo2:         Optional[float] = None
    bp_systolic:  float
    bp_diastolic: float
    glucose:      float
    temperature:  Optional[float] = 36.6  # Body temp °C
    timestamp:    Optional[datetime] = None

    def get_spo2(self) -> float:
        return self.spO2 if self.spO2 is not None else (self.spo2 or 98.0)

class VitalsResponse(BaseModel):
    user_id:       str
    heart_rate:    float
    spO2:          float
    bp_systolic:   float
    bp_diastolic:  float
    glucose:       float
    temperature:   float = 36.6
    timestamp:     Optional[datetime] = None
    id:            Optional[str] = None
    alert_triggered: bool = False
    alert_message:   Optional[str] = None
