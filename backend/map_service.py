import os
import requests
from bs4 import BeautifulSoup
from config import get_map_search_queries
from urllib.parse import urljoin

_GENERIC_NAMES = {"mall", "store", "shop", "market", "center", "centre", "plaza"}


def get_venue_context(latitude, longitude):
    """Return (venue_name, address_string) for the given coordinates."""
    api_key = os.getenv("GOOGLE_MAPS_KEY")
    if not api_key:
        print("Error: GOOGLE_MAPS_KEY not found.")
        return None, "Unknown Location"

    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"

    # (type, radius_m) — tighter for indoor venues, looser for airports/campuses
    searches = [
        ("shopping_mall", 200),
        ("airport", 2000),
        ("hospital", 500),
        ("university", 1000),
        ("store", 150),
        ("point_of_interest", 300),
    ]

    for place_type, radius in searches:
        try:
            params = {
                "location": f"{latitude},{longitude}",
                "radius": radius,
                "type": place_type,
                "key": api_key,
            }
            response = requests.get(url, params=params, timeout=10)
            data = response.json()
            results = data.get("results", [])
            if not results:
                continue

            place = results[0]
            name = place.get("name", "")
            vicinity = place.get("vicinity", "Unknown Location")

            # If Google returned a single generic word ("Mall", "Store"), use the
            # first meaningful segment of the vicinity string as the venue name instead.
            if name.lower() in _GENERIC_NAMES or len(name) <= 5:
                first_segment = vicinity.split(",")[0].strip()
                if len(first_segment) > len(name):
                    name = first_segment

            print(f"Google Places found [{place_type}]: {name} | {vicinity}")
            return name, vicinity
        except Exception as e:
            print(f"Google Places Error ({place_type}): {e}")

    print("Google Places returned no results for these coordinates.")
    return None, "Unknown Location"


def find_venue_map(address_string, venue_name=None):
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key:
        print("Error: TAVILY_API_KEY not found.")
        return None

    # Build search term: venue name + city to prevent cross-city mixups
    # vicinity from Places API is typically "123 Main St, Durham" — grab city after last comma
    city_hint = ""
    if address_string and address_string != "Unknown Location":
        parts = address_string.split(",")
        if len(parts) >= 2:
            city_hint = parts[-1].strip()

    search_term = venue_name if venue_name else address_string
    if city_hint and venue_name and city_hint.lower() not in venue_name.lower():
        search_term = f"{venue_name} {city_hint}"

    queries = get_map_search_queries(search_term)

    headers = {"Content-Type": "application/json"}
    url = "https://api.tavily.com/search"

    # Keywords from venue name to reject obviously wrong results
    venue_keywords = []
    if venue_name:
        venue_keywords = [w.lower() for w in venue_name.split() if len(w) > 3]

    for query in queries:
        try:
            payload = {
                "api_key": api_key,
                "query": query,
                "max_results": 5,
                "include_raw_content": True
            }
            response = requests.post(url, json=payload, headers=headers, timeout=15)

            if response.status_code != 200:
                continue

            data = response.json()
            for result in data.get('results', []):
                result_url = result.get('url', '')

                # 1. Direct image/PDF file (high priority)
                if result_url.lower().endswith(('.pdf', '.jpg', '.jpeg', '.png', '.webp')):
                    if venue_keywords and not any(k in result_url.lower() for k in venue_keywords):
                        continue
                    return result_url

                # 2. Scrape known map aggregator sites
                if any(site in result_url for site in ['all-maps.com', 'mallseeker.com', 'mallscenters.com']):
                    page_resp = requests.get(result_url, timeout=10,
                                             headers={'User-Agent': 'Mozilla/5.0'})
                    if page_resp.status_code == 200:
                        soup = BeautifulSoup(page_resp.text, 'html.parser')
                        for img in soup.find_all('img'):
                            src = img.get('src', '')
                            if not src:
                                continue
                            if src.startswith('//'):
                                src = 'https:' + src
                            elif not src.startswith('http'):
                                src = urljoin(result_url, src)

                            alt_text = img.get('alt', '').lower()
                            src_lower = src.lower()

                            is_map_type = any(k in src_lower or k in alt_text for k in ['map', 'directory', 'floor', 'plan'])
                            matches_venue = True
                            if venue_keywords:
                                matches_venue = any(k in src_lower or k in alt_text for k in venue_keywords)

                            if not (is_map_type and matches_venue):
                                continue

                            junk = ['menu', 'icon', 'logo', 'button', 'social', 'avatar', 'advert']
                            if any(j in src_lower for j in junk):
                                continue

                            if any(ext in src_lower for ext in ['.jpg', '.jpeg', '.png', '.webp']):
                                print(f"Found map candidate for {venue_name}: {src}")
                                return src

        except Exception as e:
            print(f"Tavily Search Error: {e}")
            continue

    print(f"No map found for {venue_name}. Check search queries in config.py.")
    return None
