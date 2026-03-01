# Steplight
**MIT Beaverworks Create Challenge** — Arjun Rao & Anil Chintapalli

Spatial navigation companion for users with coloboma (partial vision loss).
Camera + Claude vision + TTS → real-time spoken guidance.

---

## Structure

```
backend/        Flask API (VLM vision, map context)
mobile_app/     Flutter app (camera, GPS, TTS/STT)  ← run flutter create to scaffold
```

See [AGENTS.md](AGENTS.md) for architecture, setup, and development notes.
