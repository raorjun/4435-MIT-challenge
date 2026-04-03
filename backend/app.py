from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

from map_service import get_venue_context, find_venue_map
from vision_service import extract_venue_data, get_spatial_narration

app = Flask(__name__)
CORS(app)

# Single-user cache: Holds the extracted JSON for the current venue
venue_cache = {"current": {"bathrooms": [], "stores": [], "address": "Unknown"}}

@app.route('/enter_venue', methods=['POST'])
def enter_venue():
    data = request.json
    lat, lng = data.get('lat'), data.get('lng')

    venue_name, address = get_venue_context(lat, lng)
    map_url = find_venue_map(address, venue_name)

    # Always cache venue identity so the VLM knows where it is, even without a map
    base_cache = {
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
            "message": "No floor plan found — navigating by camera only."
        })

    try:
        map_resp = requests.get(map_url, timeout=15)
        mime_type = 'image/png' if map_url.endswith('.png') else 'image/jpeg'

        extracted_data = extract_venue_data(map_resp.content, mime_type)
        extracted_data['address'] = address
        extracted_data['venue_name'] = venue_name or "Unknown Venue"
        extracted_data['has_map'] = True

        venue_cache['current'] = extracted_data

        return jsonify({
            "success": True,
            "venue": venue_name or address,
            "bathrooms_found": len(extracted_data.get('bathrooms', [])),
            "stores_found": len(extracted_data.get('stores', [])),
            "map_found": True,
        })
    except Exception as e:
        venue_cache['current'] = base_cache
        return jsonify({"success": False, "error": str(e)})


@app.route("/vision/navigate", methods=["POST"])
def navigate():
    """Triggered EVERY 5 SECONDS by Flutter's camera loop."""
    image_file = request.files.get('image')
    destination = request.form.get('destination', 'the nearest exit')
    intent = request.form.get('intent', '')

    if not image_file:
        return jsonify({"error": "No image provided"}), 400

    image_bytes = image_file.read()

    # Grab the cached JSON (costs 0 API tokens!)
    current_venue_data = venue_cache.get('current', {})
    narration = get_spatial_narration(
        camera_bytes=image_bytes,
        destination=destination,
        venue_data=current_venue_data,
        user_intent=intent
    )

    return jsonify({"narration": narration})

if __name__ == '__main__':
    print('Starting Steplight API...')
    app.run(host='0.0.0.0', port=5000, debug=True)