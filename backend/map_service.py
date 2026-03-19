from opencage.geocoder import OpenCageGeocode
import os
from dotenv import load_dotenv

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

