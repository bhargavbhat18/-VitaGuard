async def send_alert_notification(fcm_token: str, alert_message: str):
    try:
        from firebase_admin import messaging
        messaging.send(messaging.Message(
            notification=messaging.Notification(title="VitalGuard Alert", body=alert_message),
            data={"type":"vital_alert","message":alert_message},
            token=fcm_token))
    except Exception as e:
        print(f"FCM error: {e}")
