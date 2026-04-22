"""
VitalGuard SMS Service
======================
Uses Fast2SMS (fast2sms.com) — India-specific, no sender verification needed.
Falls back to Twilio if TWILIO_* env vars are set.
Falls back to console simulation if neither is configured.

Default emergency contacts are always notified on every alert.
"""

import os
import time
import asyncio
import httpx
from typing import List

# ── Config ──────────────────────────────────────────────────────

# Fast2SMS — preferred for India (sign up at fast2sms.com for free API key)
FAST2SMS_KEY = os.getenv("FAST2SMS_API_KEY", "")

# Twilio — international fallback
TWILIO_SID   = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM  = os.getenv("TWILIO_PHONE_FROM", "")

# ── Hardcoded emergency contacts (always notified) ──────────────
DEFAULT_EMERGENCY_NUMBERS = ["8073199677", "8073897451"]

# ── Rate-limiting: prevent SMS spam (1 SMS per user per 5 min) ──
_last_sms_time: dict[str, float] = {}
SMS_COOLDOWN_SECONDS = 300  # 5 minutes


def _is_rate_limited(user_id: str) -> bool:
    now = time.time()
    last = _last_sms_time.get(user_id, 0)
    if now - last < SMS_COOLDOWN_SECONDS:
        remaining = int(SMS_COOLDOWN_SECONDS - (now - last))
        print(f"[SMS] Rate-limited for user {user_id} — {remaining}s remaining")
        return True
    _last_sms_time[user_id] = now
    return False


def _fmt_indian(number: str) -> str:
    """Normalize to 10-digit Indian mobile number."""
    n = number.strip().replace(" ", "").replace("-", "")
    if n.startswith("+91"):
        n = n[3:]
    elif n.startswith("91") and len(n) == 12:
        n = n[2:]
    return n


async def _send_fast2sms(numbers: List[str], message: str) -> dict:
    """Send SMS via Fast2SMS bulk API."""
    cleaned = [_fmt_indian(n) for n in numbers if n]
    if not cleaned:
        return {"sent": False, "error": "No valid numbers"}

    url = "https://www.fast2sms.com/dev/bulkV2"
    params = {
        "authorization": FAST2SMS_KEY,
        "message": message,
        "language": "english",
        "route": "q",           # Quick SMS (transactional)
        "numbers": ",".join(cleaned),
    }
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, params=params)
        data = resp.json()
        return {"sent": data.get("return", False), "response": data}


async def _send_twilio(numbers: List[str], message: str) -> dict:
    """Send SMS via Twilio (international)."""
    from twilio.rest import Client
    client = Client(TWILIO_SID, TWILIO_TOKEN)
    results = []
    for number in numbers:
        if not number:
            continue
        # Add +91 prefix if it's an Indian number without country code
        to = number if number.startswith("+") else f"+91{_fmt_indian(number)}"
        try:
            msg = client.messages.create(body=message, from_=TWILIO_FROM, to=to)
            results.append({"number": to, "sid": msg.sid, "status": msg.status})
        except Exception as e:
            results.append({"number": to, "error": str(e)})
    return {"sent": True, "results": results}


async def _dispatch(numbers: List[str], message: str) -> dict:
    """Route to Fast2SMS → Twilio → simulation, in that order."""
    if FAST2SMS_KEY and FAST2SMS_KEY != "your_fast2sms_key_here":
        return await _send_fast2sms(numbers, message)

    if TWILIO_SID and TWILIO_SID != "your_account_sid_here":
        return await _send_twilio(numbers, message)

    # Simulation mode
    cleaned = [_fmt_indian(n) for n in numbers if n]
    print(f"\n{'='*50}")
    print(f"[SMS SIMULATION] To: {', '.join(cleaned)}")
    print(f"[SMS SIMULATION] Message:\n{message}")
    print(f"{'='*50}\n")
    return {"sent": True, "mode": "simulation",
            "note": "Add FAST2SMS_API_KEY or TWILIO_* to .env to send real SMS"}


# ── Public API ─────────────────────────────────────────────────

async def send_alert_sms(
    user_id: str,
    patient_name: str,
    alert_message: str,
    location: dict = None,
    extra_numbers: List[str] = None,
) -> dict:
    """
    Send an alert SMS to all emergency contacts.
    Called automatically when vitals breach thresholds.
    Rate-limited to once every 5 minutes per user.
    """
    if _is_rate_limited(user_id):
        return {"sent": False, "reason": "rate_limited"}

    lat = location.get("lat", 0) if location else 0
    lng = location.get("lng", 0) if location else 0
    maps = f"https://maps.google.com/?q={lat},{lng}" if lat else ""

    message = (
        f"🚨 VITALGUARD HEALTH ALERT\n"
        f"Patient: {patient_name}\n"
        f"Alert: {alert_message}\n"
        f"Time: {_now_ist()}\n"
        f"{f'Location: {maps}' if maps else ''}"
    ).strip()

    # Combine hardcoded numbers + any user-specific emergency contact
    all_numbers = list(DEFAULT_EMERGENCY_NUMBERS)
    if extra_numbers:
        all_numbers += [n for n in extra_numbers if n and n not in all_numbers]

    result = await _dispatch(all_numbers, message)
    print(f"[SMS] Alert sent to {all_numbers}: {result}")
    return result


async def send_sos_sms(
    to_phone: str,
    patient_name: str,
    alert_message: str,
    location: dict = None,
) -> dict:
    """Send SOS SMS — called when user presses the SOS button."""
    lat = location.get("lat", 0) if location else 0
    lng = location.get("lng", 0) if location else 0

    message = (
        f"🚨 VITALGUARD SOS EMERGENCY\n"
        f"Patient: {patient_name}\n"
        f"Alert: {alert_message}\n"
        f"Time: {_now_ist()}\n"
        f"Location: https://maps.google.com/?q={lat},{lng}\n"
        f"Emergency services have been notified."
    )

    all_numbers = list(DEFAULT_EMERGENCY_NUMBERS)
    if to_phone and to_phone not in all_numbers:
        all_numbers.append(to_phone)

    return await _dispatch(all_numbers, message)


async def send_family_alert(
    family_phone: str,
    family_name: str,
    patient_name: str,
    alert_message: str,
    location: dict = None,
) -> dict:
    """Send follow-up family alert — called after SOS trigger."""
    lat = location.get("lat", 0) if location else 0
    lng = location.get("lng", 0) if location else 0

    message = (
        f"URGENT: {patient_name} needs immediate help!\n"
        f"VitalGuard: {alert_message}\n"
        f"Location: https://maps.google.com/?q={lat},{lng}\n"
        f"Emergency services have been notified."
    )

    all_numbers = list(DEFAULT_EMERGENCY_NUMBERS)
    if family_phone and family_phone not in all_numbers:
        all_numbers.append(family_phone)

    return await _dispatch(all_numbers, message)


def _now_ist() -> str:
    """Return current time in IST (UTC+5:30)."""
    from datetime import datetime, timezone, timedelta
    ist = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(ist).strftime("%d %b %Y, %I:%M %p IST")
