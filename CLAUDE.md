# CLAUDE.md — Steplight

## Project Definition
A technical prototype for a camera-to-speech navigation assistant. It uses a mobile camera feed and a Vision-Language Model (VLM) to provide spatial awareness and routing for a user with **Coloboma** (partial vision, high light sensitivity).

### What it IS
* **A Technical Loop:** Phone Camera → Flask Backend → VLM API → Mobile TTS.
* **Accessibility Tool:** Specifically handles high-contrast UI and light-sensitive display constraints.
* **Spatial Assistant:** Focuses on environmental narration and floor-plan-to-position mapping.

### What it is NOT
* **An Obstacle Detector:** Not a replacement for a cane or guide dog (no low-latency LiDAR/Ultrasonic).
* **A General Vision App:** Not for reading menus or identifying objects in isolation.
* **A Final Product:** No production-grade security, user accounts, or offline processing yet.

---

## Repo Structure
```
├── backend/
│   ├── app.py              # Entry point (Routes: /vision, /map-context)
│   ├── vision.py           # VLM API abstraction (Single source of truth for VLM)
│   ├── map_utils.py        # Logic for parsing floor plans/GPS
│   └── requirements.txt
├── mobile_app/             # Flutter project
├── CLAUDE.md
└── README.md

---

## Agent Rules (Technical Guardrails)

1. **Strict Domain Separation:** Keep Flutter (UI/Sensors) and Flask (Logic/VLM) decoupled.
2. **No Direct API Calls:** Mobile app **must not** call VLM or Map APIs directly. Everything goes through the Flask backend.
3. **VLM Agnostic:** Keep `vision.py` modular. Do not hardcode provider-specific SDKs into the main logic.
4. **Minimalist Filesystem:** Do not create utility folders or refactor existing code unless it blocks the primary loop.
5. **No Database:** Use in-memory sessions for the prototype phase.
6. **No Deployment/CI-CD:** Focus only on local `localhost` execution.

---

## Current Technical Priorities

1. **The "Big Text" Theme:** Implement the high-contrast (Pure Black #000000) Material 3 theme in Flutter.
2. **The Core Loop:** Establish a stable POST request sending image bytes from Flutter to Flask.
3. **Spatial Prompting:** Develop a system prompt for the VLM that outputs spatial coordinates and relative distances.
4. **Input:** Simple Speech-to-Text (STT) for destination setting.

---

## Technical Constraints (Coloboma-Specific)

* **Zero-Glare UI:** The frontend must strictly use black backgrounds to prevent light scatter.
* **Clamped Scaling:** Typography must support 1.0x to 2.5x scaling without layout overflow.
* **Haptic Affirmation:** All successful API responses must trigger a haptic pul