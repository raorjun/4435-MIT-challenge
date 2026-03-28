# Steplight Backend (Modular Prototype)

This backend powers a camera-to-speech navigation loop for indoor guidance.

## Modules

- `app.py` - Flask API routes and request validation.
- `vision_service.py` - camera-frame narration via Gemini.
- `search_service.py` - venue/map URL discovery (Nominatim + Tavily + HTML parsing).
- `map_service.py` - map landmark extraction and geocoding helpers.
- `venue_service.py` - orchestration + in-memory venue context cache.

## API Endpoints

- `GET /health`
- `POST /vision/navigate` (multipart form with `image`, optional `destination`, `intent`, `lat`, `lng`)
- `POST /venue/enter` (JSON: `latitude`, `longitude`)
- `POST /venue/navigate` (JSON: `image` base64, optional `destination`, `intent`)

Backward-compatible aliases are also available:
- `POST /enter_venue`
- `POST /navigate`

## Environment Variables

- `GOOGLE_API_KEY` (required)
- `TAVILY_API_KEY` (required for `/venue/enter`)
- `OPENCAGE_API_KEY` (optional, used for `/vision/navigate` lat/lng map context)

## Quick Start

```bash
pip install -r requirements.txt
python app.py
```

## Local Smoke Test

```bash
python smoke_test.py
```

