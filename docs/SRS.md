# Software Requirements Specification — VitalGuard v2.0

## Phase 1 Requirements
| ID | Requirement | Status |
|----|-------------|--------|
| FR-01 | Login/Signup with email + password | ✅ Done |
| FR-02 | Profile: name, age, blood group | ✅ Done |
| FR-03 | Emergency contact: name, relation, phone | ✅ Done |
| FR-04 | Doctor details: name, phone, hospital | ✅ Done |
| FR-05 | Python simulator — JSON every 5 min | ✅ Done |
| FR-06 | Simulator format: {user_id, heart_rate, spO2, timestamp} | ✅ Done |
| FR-07 | Real-time dashboard with vital cards | ✅ Done |
| FR-08 | Threshold alerts: if spO2<92%, if HR>110 etc | ✅ Done |
| FR-09 | Browser push notifications on alert | ✅ Done |
| FR-10 | Medication reminders based on health data | ✅ Done |

## Phase 2 Requirements
| ID | Requirement | Status |
|----|-------------|--------|
| FR-11 | 10-second Apple-style SOS countdown | ✅ Done |
| FR-12 | Twilio SMS to family + doctor | ✅ Done |
| FR-13 | Hospital web portal | ✅ Done |
| FR-14 | Live ambulance tracking on map | ✅ Done |
| FR-15 | ML predictive analysis (NumPy regression) | ✅ Done |
| FR-16 | Autonomous SOS dispatch on countdown expiry | ✅ Done |
| FR-17 | SRS + DFD + UML + Project Report | ✅ Done |

## Threshold Logic
```
if heart_rate > 110 → HIGH HR alert
if heart_rate < 50  → LOW HR alert
if spO2 < 92        → LOW SpO2 alert (Phase 1 spec)
if bp_systolic > 140 → HIGH BP alert
if glucose > 180    → HIGH glucose → Insulin reminder
if glucose < 70     → LOW glucose → Sugar intake reminder
```
