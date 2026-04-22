# VitalGuard — Project Report

## Abstract
VitalGuard is a real-time health monitoring system using simulated IoT data.
It detects medical emergencies via threshold logic and ML prediction, then
autonomously dispatches help via SOS countdown, Twilio SMS, and ambulance tracking.

## Phase 1 — Completed
- Login/Signup with profile (family contact + doctor details)
- Python simulator: NumPy-based realistic vitals every 5 minutes
- Flutter dashboard: 4 live vital cards (HR, SpO2, BP, Glucose)
- Threshold alerts: if-else logic + browser push notifications
- Medication reminders: smart suggestions based on current vitals

## Phase 2 — Completed
- 10-second Apple-style SOS countdown (auto-dispatch on expiry)
- Twilio SMS to family + doctor (simulation mode without credentials)
- Hospital web portal: emergency queue + live map + patient snapshot
- Live ambulance tracking: moves from hospital to patient every 3s
- ML prediction: NumPy linear regression detects HR↑ + SpO2↓ pattern

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Database | MongoDB |
| Simulator | Python + NumPy |
| Maps | OpenStreetMap (flutter_map) |
| SMS | Twilio REST API |
| ML | NumPy linear regression |

## Results
All Phase 1 and Phase 2 requirements completed and tested.
