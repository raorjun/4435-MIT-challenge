import json
import os
from google import genai
from google.genai import types
from config import EXTRACTION_PROMPT, get_navigation_prompt

client = genai.Client(api_key=os.getenv('GOOGLE_API_KEY'))


def extract_venue_data(map_bytes: bytes, mime_type: str):
    try:
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[
                types.Part.from_bytes(data=map_bytes, mime_type=mime_type),
                EXTRACTION_PROMPT
            ]
        )

        text = response.text.strip()
        if text.startswith('```json'):
            text = text[7:-3]
        elif text.startswith('```'):
            text = text[3:-3]

        return json.loads(text.strip())
    except Exception as e:
        print(f"Extraction error: {e}")
        return {"bathrooms": [], "stores": []}


def get_spatial_narration(camera_bytes: bytes, destination: str, venue_data: dict,
                          user_intent: str = ""):
    bathrooms_list = "\n".join([f"- {b.get('name', 'Restroom')}: {b.get('location', '')}" for b in
                                venue_data.get('bathrooms', [])])

    stores_list = "\n".join([f"- {s.get('name', 'Store')}: {s.get('location', '')}" for s in
                             venue_data.get('stores', [])[:25]])

    full_prompt = get_navigation_prompt(bathrooms_list, stores_list, destination, user_intent)

    try:
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[
                types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg'),
                full_prompt
            ]
        )
        return response.text.strip()
    except Exception as e:
        print(f"Navigation error: {e}")
        return "Navigation service temporarily unavailable."
