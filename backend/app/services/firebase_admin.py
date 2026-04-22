import firebase_admin
from firebase_admin import credentials
from app.config import FIREBASE_CREDENTIALS_PATH
def init_firebase():
    if not firebase_admin._apps:
        try:
            cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            print("Firebase Admin SDK initialized")
        except FileNotFoundError:
            print("WARNING: Firebase credentials file not found. Continuing in development mode.")
        except Exception as e:
            print(f"WARNING: Firebase initialization failed: {e}")
