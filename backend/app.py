import time
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests as http_requests

from map_service import get_venue_context, find_venue_map
from vision_service import extract_venue_data, get_spatial_narration, RateLimitError

app = Flask(__name__)
CORS(app)

# ── In-memory session state ─────────────────────────────────────────────────

# Single-user venue cache.  Keys written by /enter_venue, read by /vision/navigate.
# map_data: list of (bytes, mime_type) — cached to avoid re-downloading on every tick.
venue_cache: dict = {
    "current": {"bathrooms": [], "stores": [], "address": "Unknown", "map_data": []}
}

# Counts navigate calls since the last enter_venue.
# call 0 → first call → send map images; call 1+ → text context only.
_nav_call_count: int = 0

# Server-side rate guard: minimum gap between Gemini calls (Flutter sends every 15 s).
_MIN_NAVIGATE_INTERVAL: float = 12.0  # seconds
_last_navigate_time: float = 0.0


# ── Routes ──────────────────────────────────────────────────────────────────

@app.route('/enter_venue', methods=['POST'])
def enter_venue():
    global _nav_call_count
    _nav_call_count = 0          # reset session counter on each venue entry

    data = request.json or {}
    lat, lng = data.get('lat'), data.get('lng')

    venue_name, address = get_venue_context(lat, lng)
    map_url = find_venue_map(address, venue_name)

    # Base cache — always written so the VLM knows the venue even without a map
    base_cache: dict = {
        "bathrooms": [],
        "stores": [],
        "address": address,
        "venue_name": venue_name or "Unknown Venue",
        "has_map": False,
        "map_data": [],
    }

    if not map_url:
        venue_cache['current'] = base_cache
        return jsonify({
            "success": True,
            "venue": venue_name or address,
            "bathrooms_found": 0,
            "stores_found": 0,
            "map_found": False,
            "message": "No floor plan found — navigating by camera only.",
        })

    try:
        if isinstance(map_url, str):
            map_url = [map_url]

        all_bathrooms: list = []
        all_stores: list = []
        map_data: list[tuple[bytes, str]] = []   # (raw_bytes, mime_type)

        for single_url in map_url:
            resp = http_requests.get(single_url, timeout=15)
            mime = 'image/webp' if single_url.endswith('.webp') else 'image/jpeg'

            # Extract structured data (one Gemini call per map, at enter_venue time only)
            extracted = extract_venue_data(resp.content, mime, single_url)
            all_bathrooms.extend(extracted.get('bathrooms', []))
            all_stores.extend(extracted.get('stores', []))

            # Cache the raw bytes so navigate calls can reuse them without re-downloading
            map_data.append((resp.content, mime))

        venue_cache['current'] = {
            'bathrooms': all_bathrooms,
            'stores': all_stores,
            'address': address,
            'venue_name': venue_name or "Unknown Venue",
            'has_map': True,
            'map_url': map_url,
            'map_data': map_data,
        }

        return jsonify({
            "success": True,
            "venue": venue_name or address,
            "bathrooms_found": len(all_bathrooms),
            "stores_found": len(all_stores),
            "map_found": True,
        })

    except RateLimitError:
        venue_cache['current'] = base_cache
        return jsonify({"success": False, "error": "Rate limit during map extraction."}), 503

    except Exception as e:
        venue_cache['current'] = base_cache
        return jsonify({"success": False, "error": str(e)})


@app.route("/vision/navigate", methods=["POST"])
def navigate():
    """Called by Flutter every 15 s.  Returns narration JSON or 503 on quota exhaustion."""
    global _nav_call_count, _last_navigate_time

    image_file = request.files.get('image')
    if not image_file:
        return jsonify({"error": "No image provided"}), 400

    destination    = request.form.get('destination', 'the nearest exit')
    intent         = request.form.get('intent', '')
    narration_style = request.form.get('narration_style', 'Concise')

    # ── Server-side rate guard ──────────────────────────────────────────────
    now = time.time()
    elapsed = now - _last_navigate_time
    if elapsed < _MIN_NAVIGATE_INTERVAL:
        remaining = int(_MIN_NAVIGATE_INTERVAL - elapsed)
        return jsonify({"narration": f"Processing — next update in {remaining}s."})

    _last_navigate_time = now
    image_bytes = image_file.read()

    # ── Session call counter ────────────────────────────────────────────────
    is_first_call = (_nav_call_count == 0)
    _nav_call_count += 1

    current_venue = venue_cache.get('current', {})

    try:
        narration = get_spatial_narration(
            camera_bytes=image_bytes,
            destination=destination,
            venue_data=current_venue,
            user_intent=intent,
            narration_style=narration_style,
            is_first_call=is_first_call,
        )
        return jsonify({"narration": narration})

    except RateLimitError:
        # Roll back the counter so the next request retries as if it were the same call
        _nav_call_count = max(0, _nav_call_count - 1)
        return jsonify({
            "narration": "System busy — please wait.",
            "rate_limited": True,
        }), 503


@app.route('/debug/cache', methods=['GET'])
def debug_cache():
    """Returns the current venue cache (bytes omitted for readability)."""
    safe = {k: v for k, v in venue_cache.get('current', {}).items() if k != 'map_data'}
    safe['map_images_cached'] = len(venue_cache.get('current', {}).get('map_data', []))
    return jsonify(safe)


if __name__ == '__main__':
    print('Starting Steplight API...')
    app.run(host='0.0.0.0', port=5000, debug=True)
