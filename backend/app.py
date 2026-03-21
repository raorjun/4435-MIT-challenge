import io

from flask import Flask, request, jsonify
from flask_cors import CORS
from vision_service import get_spatial_narration, VisionServiceError

app = Flask(__name__)
CORS(app)  # needed for cross domain connection


@app.route("/vision/navigate", methods=["POST"])
def navigate():
    image_file = request.files.get('image')
    destination = request.form.get('destination', 'the nearest exit')
    intent = request.form.get('intent', '')
    _lat_raw = request.form.get('lat', '0.0')
    _lng_raw = request.form.get('lng', '0.0')

    if not image_file:
        return jsonify({"error": "No image provided"}), 400

    image_stream = io.BytesIO(image_file.read())
    image_bytes = image_stream.getvalue()
    map_context = None

    try:
        narration = get_spatial_narration(
            image_bytes,
            destination,
            user_intent=intent,
            map_context=map_context,
        )
    except VisionServiceError as e:
        return jsonify({"error": str(e)}), 502

    return jsonify({"narration": narration})


if __name__ == '__main__':
    print('Starting Backend API...')
    app.run(host='0.0.0.0', port=5000, debug=True)
