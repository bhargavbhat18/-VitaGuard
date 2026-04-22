# System Design — VitalGuard

## Architecture
```
[Simulator] → POST /vitals → [FastAPI] → [MongoDB]
                                  ↓              ↓
                           [WebSocket]    [Predictive ML]
                                  ↓              ↓
                          [Flutter App]   [Hospital Portal]
                                  ↓
                           [Twilio SMS]
```

## DFD Level 1
- Simulator → (vitals JSON) → Backend
- Backend → (store) → MongoDB
- Backend → (threshold check) → Alert
- Backend → (broadcast) → Flutter App
- Flutter App → (SOS trigger) → Backend → Twilio + Hospital
- Backend → (ambulance dispatch) → Live tracking

## Key API Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| /auth/profile | POST | Save user + emergency contacts |
| /vitals | POST | Receive simulator data |
| /vitals/latest | GET | Flutter polls this every 5s |
| /sos/trigger | POST | Full SOS dispatch |
| /sos/ambulance/{id} | GET | Live ambulance position |
| /analysis/predict/{id} | GET | ML risk assessment |
| /hospital/emergencies | GET | Hospital portal queue |
| /hospital/ws | WS | Live hospital feed |
