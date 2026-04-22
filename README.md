# VitalGuard
# Smart Health Monitoring Ecosystem

## **Team git commit**
We are a group of developers from **GCEM (Gopalan College of Engineering and Management)**.

* **Likith D T** (Team Lead)
* **Bhargav Bhat**
* **Keerthan R**
* **Manoj V**

## Overview

VitalGuard is a comprehensive AI-powered smart health monitoring system designed to simulate, track, and analyze patient vitals in real-time. The system provides predictive insights, emergency alerts, and seamless communication between patients, doctors, and hospitals.

This project demonstrates a **complete healthcare ecosystem** including:

* Patient monitoring
* Doctor interaction
* Emergency handling (SOS)
* Hospital coordination
* AI-based predictions

---

## 🚀 Key Highlights

* Live vital monitoring dashboard
* AI-based predictive health analysis
* Emergency SOS with countdown
* Hospital portal with live data
* Live ambulance tracking simulation
* Smart medication reminders
* Multi-user system (patient, family, doctor)

---

## Features in Detail

### 1. Authentication System

* Secure Login & Signup
* Role-based access (Patient, Doctor, Family)
* Profile management

### 2. Live Dashboard

* Displays vitals such as:

  * Heart Rate
  * Temperature
  * Oxygen Levels (SpO2)
  * Live updating cards

### 3. Simulator Engine

  * Generates synthetic health data every 5 minutes
  * Mimics real IoT devices
  * Helps test system without hardware

### 4. AI Predictive Analysis

  * Uses machine learning models to
  * Detect abnormal patterns
  * Predict potential health risks

### 5. Alerts & Notifications

  * Threshold-based alerts
  * Real-time push notifications

### 6. Medication Reminder System

  * Suggests medications based on vitals
  * Automated reminders

### 7. SOS Emergency Feature

  * 10-second countdown before triggering
  * Sends alerts to:
  * Family
  * Doctors
  * Hospital portal

### 8. Hospital Portal

  * Web-based dashboard
  * Displays all patient alerts
  * Helps hospitals respond quickly

### 9. Live Ambulance Tracking

  * Simulated map tracking
  * Helps visualize emergency response

---

## Technologies Used

### Backend

* FastAPI
* Uvicorn
* MongoDB (Motor, PyMongo)
* Firebase Admin SDK
* JWT Authentication (python-jose)

### Frontend

* Flutter (Web)
* HTML/CSS (Hospital Portal)

### AI/ML

* NumPy
* Scikit-learn

### Communication

* Twilio (SMS Alerts)
* WebSockets (real-time updates)

### Utilities

* Python Dotenv
* Requests / HTTPX
* Geopy

---

## Requirements

### System Requirements

* Python 3.9+
* Node/Flutter SDK
* MongoDB running locally or cloud
* Chrome browser

### Python Dependencies

```
fastapi
uvicorn[standard]
motor
pymongo
python-dotenv
firebase-admin
pydantic
httpx
websockets
email-validator
python-jose[cryptography]
requests
numpy
scikit-learn
twilio
geopy
```

---

## How to Run the Project

### 1️. Backend Setup

```bash
cd vitalguard/backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 2️. Simulator Setup

```bash
cd vitalguard/simulator
python3 -m venv venv
source venv/bin/activate
pip install numpy requests python-dotenv
python simulator.py
```

### 3️. Flutter Web App

```bash
cd vitalguard/mobile
flutter create . --platforms web
flutter pub get
flutter run -d chrome
```

### 4️. Hospital Portal

* Open:

```
hospital_portal/index.html
```

---

## Testing Alerts

```bash
cd vitalguard/simulator
python test_alert.py
```

---

## Use of AI

VitalGuard integrates AI in the following ways:

* Predictive analysis of vitals
* Risk detection using ML models
* Smart alert triggering
* Data-driven health insights

---

## Complete Ecosystem Flow

1. Simulator generates patient data
2. Backend processes & stores data
3. Dashboard displays real-time vitals
4. AI analyzes patterns
5. Alerts triggered if abnormal
6. Notifications sent via app + SMS
7. Hospital portal receives alerts
8. SOS triggers emergency workflow

---

## Why This Approach (No Hardware)?

* Faster development and testing
* Cost-efficient
* Scalable simulation of multiple patients
* Focus on software + AI innovation

---

## Future Enhancements

* Integration with real IoT devices
* Advanced deep learning models
* Mobile app (Android/iOS release)
* Cloud deployment (AWS/GCP)

---

## Documentation

* Full API documentation available via FastAPI Swagger UI
* Accessible at:

```
http://localhost:8000/docs
```

---

## Team

Team git commit

---

## Conclusion

VitalGuard is not just a project, but a **complete smart healthcare ecosystem** combining real-time monitoring, AI intelligence, and emergency response to improve patient safety and healthcare efficiency.

