# VitalGuard — Run Guide

## 3 Terminals

### Terminal 1 — Backend
```bash
cd vitalguard/backend
python -m venv venv && source venv/bin/activate
./venv/bin/pip install fastapi "uvicorn[standard]" motor pymongo python-dotenv \
  firebase-admin pydantic httpx websockets email-validator \
  "python-jose[cryptography]" requests numpy scikit-learn twilio geopy
./venv/bin/python -m uvicorn main:app --reload --port 8000
```

### Terminal 2 — Simulator
```bash
cd vitalguard/simulator
python3 -m venv venv && source venv/bin/activate
./venv/bin/pip install numpy requests python-dotenv
./venv/bin/python simulator.py
```

### Terminal 3 — Flutter
```bash
cd vitalguard/mobile
flutter create . --platforms web
flutter pub get
flutter run -d chrome
```

### Terminal 4 — Hospital Portal
Open `hospital_portal/index.html` in Chrome

## Test Alert
```bash
cd vitalguard/simulator && ./venv/bin/python test_alert.py
```

## All Requirements Covered
- ✅ Login / Signup / Profile (family + doctor)
- ✅ Simulator JSON every 5 min
- ✅ Live dashboard cards
- ✅ Threshold alerts + push notifications
- ✅ Medication reminders (based on vitals)
- ✅ 10-second SOS countdown
- ✅ Twilio SMS
- ✅ Hospital portal
- ✅ Live ambulance map
- ✅ ML predictive analysis
- ✅ Full documentation
