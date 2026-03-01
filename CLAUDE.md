# CLAUDE.md — Steplight

## What this app does

A conversational navigation assistant for people with partial vision loss (specifically coloboma).
The user speaks a destination ("where's the bathroom?"), the app uses the phone camera + a vision model
to understand their environment, and guides them with warm, continuous narration — not robotic one-shot commands.
Think of it as a patient, encouraging guide in their pocket.

---

## Stack

- **Flutter (mobile):** camera feed, speech-to-text, text-to-speech, GPS
- **Flask (backend):** VLM API calls, map context, session management
- **VLM (TBD):** vision + language — the core intelligence. API provider not locked in yet. All calls go through `backend/vision.py`.

---

## Repo structure

```
/
├── backend/
│   ├── app.py              # Flask entry point — routes: /health, /vision, /map-context
│   ├── vision.py           # VLM API calls (one place, don't call from elsewhere)
│   ├── map_utils.py        # map/floor plan logic (placeholder)
│   └── requirements.txt
├── mobile_app/             # Flutter project (run `flutter create mobile_app` to scaffold)
├── CLAUDE.md               # this file
└── README.md
```

---

## Running locally

### Backend
```bash
cd backend
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # add your VLM API key
python app.py           # runs on http://localhost:5000
```

### Mobile app (once scaffolded)
```bash
cd mobile_app
flutter pub get
flutter run
# Point backend URL to http://localhost:5000 in app config
```

---

## The user: Aditi

The primary user has coloboma — her visual field has gaps, she's light-sensitive, and she can see *some* things.

- **Never assume total blindness.** Guidance should be calibrated to what she can likely perceive.
- **Tone matters as much as accuracy.** Responses should feel like a calm friend, not a screen reader.
  - "You're doing great, keep walking straight" beats "Corridor detected."
  - Narrate continuously and warmly. Don't just answer and stop.
- When writing prompts sent to the VLM, the system prompt must reflect Aditi's specific situation — not be a generic "describe this image" call.

---

## Agent rules

1. **Don't create new files** unless explicitly asked or obviously necessary for running code.
2. **Don't refactor working code** without being asked.
3. **If unsure about scope, do less and ask.** Early prototype — keep it lean.
4. **All VLM API calls go through `backend/vision.py`.** Don't call the API from the mobile app or anywhere else.
5. **Flutter and backend are separate** — don't mix concerns between them.
6. **No deployment config, ML training folders, or data pipelines** until explicitly needed.
7. The VLM provider is not locked in yet. Keep `vision.py` easy to swap out (don't hardcode provider-specific patterns everywhere).

---

## Current priorities

1. Working **camera → Flask → VLM → TTS** loop end to end (rough is fine)
2. Basic **STT** for destination input
3. A good **system prompt** for the VLM that fits Aditi's needs — compassionate, spatial, calibrated to partial vision

---

## What not to do

- Don't add WiFi fingerprinting, VIO/ARKit, or ML model training infrastructure — that's future work
- Don't optimize for scale or add caching layers
- Don't add a database until there's a clear reason
- Don't clean up or reorganize code unprompted
