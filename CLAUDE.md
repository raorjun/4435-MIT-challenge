# CLAUDE.md — Steplight

## Project Definition
A technical prototype for a camera-to-speech navigation assistant. It uses a mobile camera feed and a Vision-Language Model (VLM) to provide spatial awareness and routing for a user with **Coloboma** (partial vision, high light sensitivity).

### What it IS
* **A Technical Loop:** Phone Camera → Flask Backend → VLM API → Mobile TTS.
* **Accessibility Tool:** Specifically handles high-contrast UI and light-sensitive display constraints.
* **Spatial Assistant:** Focuses on environmental narration and floor-plan-to-position mapping.
* **Live Prototype:** Core loop is functional with 5-second camera capture intervals, venue extraction, and real-time narration.

### What it is NOT
* **An Obstacle Detector:** Not a replacement for a cane or guide dog (no low-latency LiDAR/Ultrasonic).
* **A General Vision App:** Not for reading menus or identifying objects in isolation.
* **A Final Product:** No production-grade security, user accounts, or offline processing yet.

---

## Repo Structure (Current)
```
├── backend/
│   ├── app.py                # Entry point (Routes: /enter_venue, /vision/navigate)
│   ├── config.py             # VLM prompts (extraction, navigation)
│   ├── vision_service.py     # Gemini 3.1 Flash Lite API calls
│   ├── map_service.py        # Venue context & map lookup via Google Places + search
│   └── requirements.txt
├── mobile_app/               # Flutter project
│   ├── lib/
│   │   ├── main.dart         # App entry, dark theme (#000000), text scale clamp (1.0x–2.5x)
│   │   ├── screens/
│   │   │   └── main_navigation_screen.dart   # 3-tab nav (Navigate, Saved, Settings)
│   │   ├── components/
│   │   │   ├── camera_feed.dart              # Live camera + 5-sec capture loop
│   │   │   ├── narration_box.dart            # Display & replay last narration
│   │   │   └── safe_tap_button.dart          # High-contrast tap targets
│   │   └── theme/
│   │       └── theme.dart    # AppTheme (black bg, Material 3, accessible colors)
│   ├── pubspec.yaml
│   └── [Android/iOS scaffolding]
├── TEST.md                   # Backend setup, device IP override, validation steps
├── CLAUDE.md
└── README.md
```

---

## Core Architecture

### Two-Phase Approach (Backend)
1. **Venue Extraction** (`POST /enter_venue`)
   - Takes `lat`, `lng` → looks up venue name via Google Places API
   - Downloads venue map (mall directory, floor plan, etc.)
   - Sends map image to Gemini 3.1 Flash Lite with `EXTRACTION_PROMPT`
   - Extracts JSON: `{bathrooms: [{name, floor, nearest_stores, location}], stores: [{name, location}]}`
   - **Caches result** in single-user in-memory dict (no database)

2. **Spatial Navigation** (`POST /vision/navigate`, every 5 seconds)
   - Receives: `image` (JPEG bytes), `destination` (string), `intent` (raw voice text), `lat/lng` (hardcoded 0.0 for now)
   - Grabs cached venue data
   - Sends camera frame + venue context + `NAVIGATION_PROMPT` to Gemini
   - Returns narration: ≤2 sentences, clock-face directions, glare alerts, estimated distance

### Mobile Device Loop (Flutter)
- **Camera:** Continuous live feed on-screen
- **Audio Input:** Voice destination via SpeechToText on-device (no network latency)
- **Timer:** Every 5 seconds, capture frame, resize/compress to JPEG, POST to `/vision/navigate`
- **Audio Output:** Receive narration JSON, play via FlutterTts
- **UI:** Tap button to repeat last narration; displays current narration in large text

---

## Agent Rules (Technical Guardrails)

1. **Strict Domain Separation:** Keep Flutter (UI/Sensors) and Flask (Logic/VLM) decoupled.
2. **No Direct API Calls:** Mobile app **must not** call VLM or Map APIs directly. Everything goes through the Flask backend.
3. **VLM Agnostic:** Keep `vision_service.py` modular to swap providers (currently Gemini; extendable to Claude, etc.).
4. **Minimalist Filesystem:** Do not create utility folders or refactor existing code unless it blocks the primary loop.
5. **No Database:** Use in-memory sessions for the prototype phase.
6. **No Deployment/CI-CD:** Focus only on local `localhost` execution.

---

## Implementation Status

### ✅ Implemented
1. **The "Big Text" Theme:** High-contrast (#000000) Material 3 theme in Flutter.
2. **The Core Loop:** Stable POST request cycle sending image bytes from Flutter to Flask every 5 seconds.
3. **Spatial Prompting:** System prompt generates navigation instructions with clock-face directions, glare warnings, and distances.
4. **Voice Input:** STT captures destination; raw intent text sent to VLM for conversational routing (e.g., "sports clothes" → nearest clothing stores).
5. **TTS Output:** Narration played back via FlutterTts; tap button repeats last message.
6. **Venue Extraction:** Gemini extracts bathrooms, stores, and landmarks from venue maps in structured JSON.
7. **Text Scaling:** Clamped to 1.0x–2.5x; no layout overflow.
8. **Haptic Feedback:** Tap actions trigger light haptic pulse; narration success triggers haptic confirmation.

### 🚧 In Development / Known Limitations
- **GPS Integration:** Currently hardcoded `lat=0.0, lng=0.0`; real GPS not yet connected.
- **Persistent Destinations:** No saved places yet (Settings tab is placeholder); destination resets on each app restart.
- **Multi-User Sessions:** In-memory cache only supports one active user.
- **Network Resilience:** No explicit retry logic; timeouts may leave mobile in "waiting" state (see TEST.md for timeout recommendations).
- **Venue Map Source:** Currently searches Google Maps, Pinterest, MallSeeker; not all venues have indexed maps.

---

## Technical Constraints (Coloboma-Specific)

* **Zero-Glare UI:** Frontend strictly uses black (#000000) backgrounds to prevent light scatter.
* **Clamped Scaling:** Typography supports 1.0x to 2.5x scaling without layout overflow.
* **Haptic Affirmation:** Successful API responses trigger haptic pulses for audio-free confirmation.
* **Glare Alerts:** Narration includes warnings if camera detects bright skylights or windows.
* **Concise Narration:** Max 2 sentences to avoid information overload.

---

## Development & Testing

### Quick Start
1. **Backend:** See `backend/requirements.txt`. Run `python app.py` (Flask runs on `0.0.0.0:5000`).
   - Requires: `GOOGLE_API_KEY` environment variable set.
2. **Mobile:** Run `flutter pub get` in `mobile_app/`, then deploy via `flutter run --dart-define=STEP_LIGHT_BACKEND_URL=http://<backend-ip>:5000`.
3. **Validation:** See `TEST.md` for full setup steps, endpoint testing, and device IP overrides (Android emulator, iOS simulator, physical phone).

### Key Implementation Details
- **Venue Cache:** Single in-memory dict keyed on `current`. Call `/enter_venue` first to populate; subsequent calls to `/vision/navigate` reuse cache.
- **Venue Map Lookup:** Uses Google Places API to get venue name, then searches Pinterest/MallSeeker/Google Maps for directory/floor plan PDFs/images.
- **VLM Provider:** Hardcoded to Gemini 3.1 Flash Lite Preview. To swap providers (e.g., Claude), modify `vision_service.py` and `config.py`.
- **Text Encoding:** Image JPEG compression happens client-side (Flutter) to reduce bandwidth; backend receives bytes directly.
- **Narration State:** Mutable in Flutter (`_currentNarration`); NarrationBox displays and can replay via TTS.

### Notes from Development
- Keep camera capture loop and HTTP requests on a timer; do not block on network errors.
- Chat narration may be partial or fail silently if venue data is sparse; graceful fallback to "continue forward" is acceptable.
- For multi-user production, replace in-memory cache with session tokens or a lightweight database (e.g., SQLite, Redis).
- Glare detection relies on VLM's interpretation of image brightness; not a substitute for real sensor input.