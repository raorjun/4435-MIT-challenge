from opencage.geocoder import OpenCageGeocode
import os
from dotenv import load_dotenv
import requests

load_dotenv()


def get_public_space_name(lat, lng):
    api_key = os.getenv("OPENCAGE_API_KEY")
    if api_key is None:
        print("No OpenCage API key provided")
        return None

    geocoder = OpenCageGeocode(api_key)
    try:
        results = geocoder.reverse_geocode(lat, lng)
        if results and len(results) > 0:
            components = results[0]['components']
            space_name = (
                    components.get('mall') or
                    components.get('university') or
                    components.get('aeroway') or
                    components.get('hospital') or
                    components.get('stadium') or
                    components.get('theme_park') or
                    components.get('building')
            )
            return space_name
    except Exception as e:
        print(f"Geocode error: {e}")
    return None


def get_indoor_landmarks(space_name):
    if not space_name:
        return []
    overpass_url = "http://overpass-api.de/api/interpreter"
    query = f"""
    [out:json][timeout:15];
    area[name="{space_name}"]->.searchArea;
    (
      node["name"](area.searchArea);
      way["name"](area.searchArea);
      relation["name"](area.searchArea);
    );
    out tags;
    """
    try:
        response = requests.get(overpass_url, params={"data": query}, timeout=10)
        response.raise_for_status()
        data = response.json()

        landmarks = {el.get('tags', {}).get('name') for el in data.get('elements', [])}
        clean_landmarks = [name for name in landmarks if name]
        return clean_landmarks
    except Exception as e:
        print(f"Overpass error: {e}")
        return []
