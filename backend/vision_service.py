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

_GEMINI_MODEL = 'models/gemini-3-flash-preview'

# Keywords that identify a Gemini 429 / quota error across SDK versions.
_RATE_LIMIT_MARKERS = ('429', 'resource_exhausted', 'quota', 'rate limit', 'rateLimitExceeded')


class RateLimitError(Exception):
    """Raised when Gemini returns a 429 / RESOURCE_EXHAUSTED response."""


def _is_rate_limit(exc: Exception) -> bool:
    msg = str(exc).lower()
    return any(m in msg for m in _RATE_LIMIT_MARKERS)


def extract_venue_data(map_bytes: bytes, mime_type: str, map_url: str = "") -> dict:
    """Extract structured venue data from a single map image."""
    floor_number = None
    if map_url:
        m = re.search(r'level[-_]?(\d+)', map_url.lower())
        if m:
            floor_number = m.group(1)
            print(f"  Detected floor from URL: {floor_number}")

    try:
        response = client.models.generate_content(
            model=_GEMINI_MODEL,
            contents=[
                types.Part.from_bytes(data=map_bytes, mime_type=mime_type),
                EXTRACTION_PROMPT,
            ],
        )

        text = response.text.strip()
        if text.startswith('```json'):
            text = text[7:-3]
        elif text.startswith('```'):
            text = text[3:-3]

        data = json.loads(text.strip())

        if floor_number:
            for item in data.get('bathrooms', []) + data.get('stores', []):
                if not item.get('floor') or item.get('floor') in ['?', 'Not specified']:
                    item['floor'] = floor_number

        return data

    except Exception as e:
        if _is_rate_limit(e):
            raise RateLimitError(str(e)) from e
        print(f"Extraction error: {e}")
        return {"bathrooms": [], "stores": []}


def get_spatial_narration(
    camera_bytes: bytes,
    destination: str,
    venue_data: dict,
    narration_style: str = "Concise",
) -> str:
    """
    Build the Gemini request for one navigation tick.

    Camera frame is always sent.  When a venue map was loaded at entry, the
    extracted store/bathroom list is injected as text — no map image bytes are
    re-sent.  This keeps every navigate call stateless and the camera primary.
    """
    bathrooms_list = "\n".join([
        f"- {b.get('name', 'Restroom')} (Floor {b.get('floor', '?')}): "
        f"near {', '.join(b.get('nearest_stores', []))}"
        for b in venue_data.get('bathrooms', [])
    ])

    stores_list = "\n".join([
        f"- {s.get('name', 'Store')}: {s.get('location', '')}"
        for s in venue_data.get('stores', [])[:25]
    ])

    venue_name = venue_data.get('venue_name', 'Unknown Location')
    has_map = venue_data.get('has_map', False)

    full_prompt = get_navigation_prompt(
        bathrooms_list, stores_list, destination,
        venue_name=venue_name, has_map=has_map, narration_style=narration_style,
    )

    contents: list = [types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg')]

    if has_map:
        contents.append(
            "CONTEXT: The venue floor plan was analyzed at entry. "
            "Use the store/bathroom list below as a reference ONLY if the camera "
            "confirms you are inside this venue — otherwise ignore it.\n\n"
            f"STORES:\n{stores_list or 'None.'}\n\n"
            f"BATHROOMS:\n{bathrooms_list or 'None.'}"
        )
        print("[Vision] Camera frame + text venue context.")
    else:
        print("[Vision] Camera-only mode — no map available.")

    contents.append(full_prompt)

    try:
        response = client.models.generate_content(model=_GEMINI_MODEL, contents=contents)
        return response.text.strip()
    except Exception as e:
        if _is_rate_limit(e):
            print(f"[Vision] Rate limit hit: {e}")
            raise RateLimitError(str(e)) from e
        print(f"[Vision] Navigation error: {e}")
        return "Navigation service temporarily unavailable."
