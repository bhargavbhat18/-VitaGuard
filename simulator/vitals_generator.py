import numpy as np

_state = {
    "heart_rate":   75.0,
    "spo2":         98.0,
    "bp_systolic":  120.0,
    "bp_diastolic": 80.0,
    "glucose":      100.0,
    "temperature":  36.6,  # Body temperature °C (normal: 36.1–37.2)
}

def generate_vitals(simulate_emergency: bool = False) -> dict:
    global _state
    if simulate_emergency:
        _state["heart_rate"]   = np.clip(_state["heart_rate"]   + np.random.uniform(2, 5),   50, 160)
        _state["spo2"]         = np.clip(_state["spo2"]         - np.random.uniform(0.5, 2),  85, 100)
        _state["bp_systolic"]  = np.clip(_state["bp_systolic"]  + np.random.uniform(1, 3),    60, 200)
        _state["glucose"]      = np.clip(_state["glucose"]      + np.random.uniform(5, 15),   50, 300)
        _state["temperature"]  = np.clip(_state["temperature"]  + np.random.uniform(0.2, 0.5),36, 42)
    else:
        _state["heart_rate"]   = np.clip(_state["heart_rate"]   + np.random.normal(0, 1.5),   50, 110)
        _state["spo2"]         = np.clip(_state["spo2"]         + np.random.normal(0, 0.3),   92, 100)
        _state["bp_systolic"]  = np.clip(_state["bp_systolic"]  + np.random.normal(0, 2.0),   90, 140)
        _state["bp_diastolic"] = np.clip(_state["bp_diastolic"] + np.random.normal(0, 1.5),   60,  90)
        _state["glucose"]      = np.clip(_state["glucose"]      + np.random.normal(0, 3.0),   70, 180)
        _state["temperature"]  = np.clip(_state["temperature"]  + np.random.normal(0, 0.05), 35.5, 37.5)

    return {k: round(float(v), 1) for k, v in _state.items()}
