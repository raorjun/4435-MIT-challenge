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
    user_intent: str = "",
    narration_style: str = "Concise",
    is_first_call: bool = True,
) -> str:
    """
    Build the Gemini request for one navigation tick.

    Token-saving session strategy
    ──────────────────────────────
    First call (is_first_call=True):
      camera frame + cached map image bytes + full system prompt
      → Gemini sees the floor plan once and anchors its orientation.

    Subsequent calls (is_first_call=False):
      camera frame + text-only context (store/bathroom list) + prompt
      → No map images re-sent; tokens spent only on the live frame.
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
        bathrooms_list, stores_list, destination, user_intent,
        venue_name=venue_name, has_map=has_map, narration_style=narration_style,
    )

    # Camera frame is always included
    contents: list = [types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg')]

    if is_first_call and has_map:
        # Send cached map bytes so Gemini can build spatial orientation once.
        map_data: list[tuple[bytes, str]] = venue_data.get('map_data', [])
        for map_bytes_item, mime in map_data:
            contents.append(types.Part.from_bytes(data=map_bytes_item, mime_type=mime))
        if map_data:
            contents.append(
                "CONTEXT: The image(s) above include the venue floor plan. "
                "Use them with the camera frame to orient the user."
            )
        print(f"[Vision] First call — sending {len(map_data)} map image(s) + camera frame.")
    elif has_map:
        # Subsequent calls: inject store directory as text only — no image re-download.
        contents.append(
            "CONTEXT: You have already analyzed the venue floor plan in a prior call. "
            "Use the store/bathroom list below and the current camera frame only. "
            "Do not request the map image again.\n\n"
            f"STORES:\n{stores_list or 'None.'}\n\n"
            f"BATHROOMS:\n{bathrooms_list or 'None.'}"
        )
        print("[Vision] Subsequent call — camera frame + text context only (no map image).")
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