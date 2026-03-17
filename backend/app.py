from flask import Flask, request, jsonify
from flask_cors import CORS
import io
from vision import get_spatial_narration
# map context for

app = Flask(__name__)
CORS(app) # needed for cross domain connection

@app.route("/vision/navigate", methods=["POST"])
def navigate():
    if "image" not in request.files:
        return jsonify({"error": "no image"}), 400

    # implement map context and then call the vlm


