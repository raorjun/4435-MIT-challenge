# Steplight Backend (Modular Prototype)

Camera-to-speech backend for indoor navigation assistance focused on coloboma constraints (partial vision and light sensitivity).

## What Changed

- Replaced the monolithic legacy backend with a modular service layout.
- Kept `app.py` as a thin Flask API layer (routing + validation + HTTP responses only).
- Split domain logic into services: vision narration, map search, map extraction, and venue orchestration.
- Added canonical venue routes under `/venue/*` while keeping temporary compatibility aliases.
- Added a small local `smoke_test.py` script for quick API sanity checks.
- Removed legacy/prototype files (`app1.py`, `upd_indoor_network.py`, `southpoint_graph.json`, `southpoint_graph.png`).

## File Responsibilities

- `app.py`
  - Registers Flask routes, CORS, request parsing, and response/error mapping.
  - Exposes `/health`, `/vision/navigate`, `/venue/enter`, `/venue/navigate`.
  - Keeps compatibility aliases: `/enter_venue`, `/navigate`.

- `vision_service.py`
  - Handles Vision-Language Model narration generation from camera frames.
  - Applies accessibility-focused prompt instructions and output shaping.

- `search_service.py`
  - Resolves a venue hint from GPS coordinates (Nominatim).
  - Searches for likely map URLs (Tavily + HTML parsing).

- `map_service.py`
  - Geocoding helpers (`get_public_space_name`) and Overpass landmark lookup.
  - Downloads map assets and extracts structured restroom/store anchors via Gemini.

- `venue_service.py`
  - Orchestrates venue-entry flow: address -> map discovery -> map extraction -> cache.
  - Orchestrates in-venue navigation by building map context and calling `vision_service`.

- `smoke_test.py`
  - Lightweight Flask test-client checks for route health and required-field validation.

- `requirements.txt`
  - Python dependencies for Flask API, Gemini client, mapping/search helpers, and parsing.

## API Endpoints

- `GET /health`
- `POST /vision/navigate`
  - Multipart form with `image`.
  - Optional: `destination`, `intent`, `lat`, `lng`.
- `POST /venue/enter`
  - JSON body: `latitude`, `longitude`.
- `POST /venue/navigate`
  - JSON body: `image` (base64).
  - Optional: `destination`, `intent`.

Compatibility aliases (temporary):
- `POST /enter_venue`
- `POST /navigate`

## Environment Variables

- `GOOGLE_API_KEY` (required)
- `TAVILY_API_KEY` (required for venue map discovery)
- `OPENCAGE_API_KEY` (optional, used for `/vision/navigate` map context)

## Quick Start

```bash
pip install -r requirements.txt
python app.py
```

## Local Smoke Test

```bash
python smoke_test.py
```
