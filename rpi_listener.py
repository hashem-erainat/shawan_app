import os
import time
import json

# Optional: install dependencies if not already installed
# pip install firebase-admin RPi.GPIO

try:
    import RPi.GPIO as GPIO
except (ImportError, RuntimeError):
    # Mock GPIO for development on non-RPi machines
    class MockGPIO:
        BCM = BOARD = IN = OUT = PUD_DOWN = FALLING = None
        def setmode(self, *args, **kwargs): pass
        def setup(self, *args, **kwargs): pass
        def add_event_detect(self, *args, **kwargs): pass
        def cleanup(self): pass
    GPIO = MockGPIO()

import firebase_admin
from firebase_admin import credentials, db

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------
# Path to your Firebase service account JSON key file.
# Replace this with the actual absolute path on the Raspberry Pi.
SERVICE_ACCOUNT_PATH = os.getenv("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json")

# The URL of your Firebase Realtime Database.
# Example: "https://your-project-id.firebaseio.com/"
DATABASE_URL = os.getenv("FIREBASE_DATABASE_URL", "https://your-project-id.firebaseio.com/")

# GPIO pin number (BCM numbering) that you want to monitor.
GPIO_PIN = int(os.getenv("GPIO_PIN", "17"))

# ------------------------------------------------------------
# Initialise Firebase Admin SDK
# ------------------------------------------------------------
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred, {"databaseURL": DATABASE_URL})

# Reference to a node in the Realtime Database where we will push events.
# Adjust the path as needed for your data model.
root_ref = db.reference("/rpi_events")

# ------------------------------------------------------------
# GPIO Setup
# ------------------------------------------------------------
GPIO.setmode(GPIO.BCM)
GPIO.setup(GPIO_PIN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

def on_pin_falling(channel):
    """Callback executed when a falling edge is detected on the monitored pin.
    It records a timestamped event in Firebase Realtime Database.
    """
    timestamp = int(time.time() * 1000)  # milliseconds since epoch
    event = {
        "pin": GPIO_PIN,
        "timestamp": timestamp,
        "type": "falling"
    }
    # Push a new child under /rpi_events with a unique key.
    root_ref.push(event)
    print(f"Event recorded: {json.dumps(event)}")

# Register the callback for falling edge detection (e.g., button press).
GPIO.add_event_detect(GPIO_PIN, GPIO.FALLING, callback=on_pin_falling, bouncetime=200)

print("Raspberry Pi listener started. Press Ctrl+C to exit.")

try:
    # Keep the script alive.
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Shutting down listener…")
finally:
    GPIO.cleanup()
