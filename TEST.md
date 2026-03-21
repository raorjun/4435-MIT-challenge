# Steplight Live Navigation Loop Test Guide

## Prerequisites
- Python 3.x
- Flutter SDK (with Android/iOS toolchains configured)
- A valid GOOGLE_API_KEY exported in your shell/environment
- Phone and backend machine on the same local network when testing on a physical device

## Backend Setup (Flask)
1. Open a terminal in `backend/`.
2. (Optional) Activate virtual environment.
3. Install dependencies:
   - `pip install -r requirements.txt`
4. Set your key:
   - PowerShell: `$env:GOOGLE_API_KEY="your_key_here"`
5. Run backend:
   - `python app.py`
6. Confirm server starts on `http://0.0.0.0:5000`.

## Mobile Setup (Flutter)
1. Open a terminal in `mobile_app/`.
2. Install packages:
   - `flutter pub get`
3. Find your laptop local IP (example: `192.168.1.34`).
4. Run app with backend override using `--dart-define`:
   - Physical phone (recommended):
     - `flutter run --dart-define=STEP_LIGHT_BACKEND_URL=http://<your-laptop-local-ip>:5000`
   - Android emulator:
     - `flutter run --dart-define=STEP_LIGHT_BACKEND_URL=http://10.0.2.2:5000`
   - iOS simulator:
     - `flutter run --dart-define=STEP_LIGHT_BACKEND_URL=http://127.0.0.1:5000`
5. If you do not pass `--dart-define`, app defaults are:
   - Android: `http://10.0.2.2:5000`
   - iOS: `http://127.0.0.1:5000`

## What The Loop Sends
- Endpoint: `POST /vision/navigate`
- Multipart fields:
  - `image` (JPEG bytes, resized/compressed in-memory)
  - `destination` (String)
  - `intent` (String)
  - `lat` = `0.0` (hardcoded)
  - `lng` = `0.0` (hardcoded)

## First Run Validation
1. Launch app and stay on the Navigate tab.
2. Tap Voice Destination and speak a goal (example: "Take me to sports clothes").
3. Point camera at a doorway or hallway landmark.
4. Wait 5 seconds for the capture loop tick.
5. Verify backend receives `/vision/navigate` requests.
6. Verify NarrationBox text updates.
7. Verify TTS immediately reads the returned narration.
8. Tap Repeat Narration and confirm the same line is read again.

## Troubleshooting
- No backend calls:
  - Confirm you are on the Navigate tab (capture loop is active only there).
  - Confirm Flask is running and reachable from device.
- Device cannot connect:
   - Use `--dart-define=STEP_LIGHT_BACKEND_URL=http://<your-laptop-local-ip>:5000`.
   - Allow Python through firewall on Private network.
- No speech capture:
  - Grant microphone permission.
- No camera frames:
  - Grant camera permission.
- No Gemini output:
  - Re-check `GOOGLE_API_KEY` and backend terminal logs.
