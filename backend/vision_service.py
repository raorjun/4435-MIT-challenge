import json
import os
import re
import requests
from google import genai
from google.genai import types
from dotenv import load_dotenv
from config import EXTRACTION_PROMPT, get_navigation_prompt

load_dotenv()

client = genai.Client(api_key=os.getenv('GOOGLE_API_KEY'))


def extract_venue_data(map_bytes: bytes, mime_type: str, map_url: str = ""):
    """Extract data from a single map, with optional floor number from URL"""
    
    # Try to extract floor number from URL
    floor_number = None
    if map_url:
        floor_match = re.search(r'level[-_]?(\d+)', map_url.lower())
        if floor_match:
            floor_number = floor_match.group(1)
            print(f"  Detected floor from URL: {floor_number}")
    
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

        data = json.loads(text.strip())
        
        # If we detected a floor number from URL, assign it to items that don't have one
        if floor_number:
            for bathroom in data.get('bathrooms', []):
                if not bathroom.get('floor') or bathroom.get('floor') in ['?', 'Not specified']:
                    bathroom['floor'] = floor_number
            
            for store in data.get('stores', []):
                if not store.get('floor') or store.get('floor') in ['?', 'Not specified']:
                    store['floor'] = floor_number
        
        return data
        
    except Exception as e:
        print(f"Extraction error: {e}")
        return {"bathrooms": [], "stores": []}


def get_spatial_narration(camera_bytes: bytes, destination: str, venue_data: dict,
                          user_intent: str = ""):
    bathrooms_list = "\n".join([f"- {b.get('name', 'Restroom')} (Floor {b.get('floor', '?')}): near {', '.join(b.get('nearest_stores', []))}"
    for b in venue_data.get('bathrooms', [])])

    stores_list = "\n".join([f"- {s.get('name', 'Store')}: {s.get('location', '')}" for s in
                             venue_data.get('stores', [])[:25]])

    full_prompt = get_navigation_prompt(
        bathrooms_list, stores_list, destination, user_intent
    )

    try:
        # Build contents: camera + ALL maps + prompt
        contents = [types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg')]
        
        # Add the map images
        map_urls = venue_data.get('map_url', [])
        if isinstance(map_urls, str):
            map_urls = [map_urls]
        
        for map_url in map_urls:
            try:
                map_resp = requests.get(map_url, timeout=30)
                mime_type = 'image/webp' if map_url.endswith('.webp') else 'image/jpeg'
                contents.append(types.Part.from_bytes(data=map_resp.content, mime_type=mime_type))
            except Exception as e:
                print(f"Error downloading map for navigation: {e}")
        
        contents.append(full_prompt)
        
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=contents
        )
        return response.text.strip()
    except Exception as e:
        print(f"Navigation error: {e}")
        return "Navigation service temporarily unavailable."