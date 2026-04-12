import time
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests as http_requests

from map_service import get_venue_context, find_venue_map
from vision_service import extract_venue_data, get_spatial_narration, RateLimitError

app = Flask(__name__)
CORS(app)

# ── In-memory session state ─────────────────────────────────────────────────

venue_cache: dict = {
    "current": {"bathrooms": [], "stores": [], "address": "Unknown", "has_map": False}
}

# Server-side rate guard: minimum gap between Gemini calls.
_MIN_NAVIGATE_INTERVAL: float = 12.0  # seconds
_last_navigate_time: float = 0.0


# ── Routes ──────────────────────────────────────────────────────────────────

@app.route('/enter_venue', methods=['POST'])
def enter_venue():
    data = request.json or {}
    lat, lng = data.get('lat'), data.get('lng')

    use_map = data.get('use_map', True)

    venue_name, address = get_venue_context(lat, lng)
    map_url = find_venue_map(address, venue_name) if use_map else None

    base_cache: dict = {
        "bathrooms": [],
        "stores": [],
        "address": address,
        "venue_name": venue_name or "Unknown Venue",
        "has_map": False,
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

        for single_url in map_url:
            resp = http_requests.get(single_url, timeout=15)
            mime = 'image/webp' if single_url.endswith('.webp') else 'image/jpeg'
            extracted = extract_venue_data(resp.content, mime, single_url)
            all_bathrooms.extend(extracted.get('bathrooms', []))
            all_stores.extend(extracted.get('stores', []))

        venue_cache['current'] = {
            'bathrooms': all_bathrooms,
            'stores': all_stores,
            'address': address,
            'venue_name': venue_name or "Unknown Venue",
            'has_map': True,
            'map_url': map_url,
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
    """Called by Flutter every 15 s. Returns narration JSON or 503 on quota exhaustion."""
    global _last_navigate_time

    image_file = request.files.get('image')
    if not image_file:
        return jsonify({"error": "No image provided"}), 400

    destination     = request.form.get('destination', 'the nearest exit')
    narration_style = request.form.get('narration_style', 'Concise')

    # Server-side rate guard
    now = time.time()
    elapsed = now - _last_navigate_time
    if elapsed < _MIN_NAVIGATE_INTERVAL:
        remaining = int(_MIN_NAVIGATE_INTERVAL - elapsed)
        return jsonify({"narration": f"Processing — next update in {remaining}s."})

    _last_navigate_time = now
    image_bytes = image_file.read()

    try:
        narration = get_spatial_narration(
            camera_bytes=image_bytes,
            destination=destination,
            venue_data=venue_cache.get('current', {}),
            narration_style=narration_style,
        )
        return jsonify({"narration": narration})

    except RateLimitError:
        return jsonify({
            "narration": "System busy — please wait.",
            "rate_limited": True,
        }), 503


@app.route('/debug/cache', methods=['GET'])
def debug_cache():
    """Returns the current venue cache."""
    safe = {k: v for k, v in venue_cache.get('current', {}).items()}
    return jsonify(safe)


if __name__ == '__main__':
    print('Starting Steplight API...')
    app.run(host='0.0.0.0', port=5000, debug=True)
