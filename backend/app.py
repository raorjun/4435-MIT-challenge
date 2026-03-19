from flask import Flask, request, jsonify
from flask_cors import CORS
from vision_service import get_spatial_narration

app = Flask(__name__)
CORS(app)  # needed for cross domain connection


@app.route("/vision/navigate", methods=["POST"])
def navigate():
    image_file = request.files.get('image')
    destination = request.form.get('destination', 'the nearest exit')

    if not image_file:
        return jsonify({"error": "No image provided"}), 400
    image_bytes = image_file.read()

    narration = get_spatial_narration(image_bytes, destination)
    return jsonify({"narration": narration})


if __name__ == '__main__':
    print('Starting Backend API...')
    app.run(host='0.0.0.0', port=5000, debug=True)
