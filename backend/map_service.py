import math
import os
import requests
from bs4 import BeautifulSoup
from config import get_map_search_queries
from urllib.parse import urljoin

_GENERIC_NAMES = {"mall", "store", "shop", "market", "center", "centre", "plaza"}


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometres between two lat/lng points."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))


def _closest_result_within(results: list, lat: float, lng: float, radius_m: int):
    """
    Return the result closest to (lat, lng) that is actually within radius_m.
    Falls back to None if every candidate is farther away than the radius.
    This prevents picking a high-review venue that's miles away.
    """
    best = None
    best_dist = float('inf')
    for r in results:
        geo = r.get('geometry', {}).get('location', {})
        rlat, rlng = geo.get('lat'), geo.get('lng')
        if rlat is None or rlng is None:
            continue
        dist_km = _haversine_km(lat, lng, rlat, rlng)
        dist_m = dist_km * 1000
        # Accept up to 20 % beyond the declared radius to handle API rounding
        if dist_m <= radius_m * 1.2 and dist_km < best_dist:
            best_dist = dist_km
            best = r
    return best


def get_venue_context(latitude, longitude):
    """Return (venue_name, address_string) for the given coordinates."""
    # Accept either key name so users don't need two separate variables
    api_key = os.getenv("GOOGLE_MAPS_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        print("Error: GOOGLE_MAPS_KEY (or GOOGLE_API_KEY) not found.")
        return None, "Unknown Location"

    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"

    # Ordered by priority: campus/building types before airport so a university
    # library doesn't resolve to an airport across town.
    searches = [
        ("shopping_mall", 800),
        ("university", 1500),
        ("hospital", 1000),
        ("transit_station", 1000),
        ("airport", 1500),
        ("establishment", 400),   # last-resort fallback
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

            # Pick the closest result that is genuinely within the search radius.
            # Do NOT use max(user_ratings_total) — it favours famous far-away venues.
            best_place = _closest_result_within(results, latitude, longitude, radius)
            if best_place is None:
                print(f"  [{place_type}] All results outside {radius} m — skipping.")
                continue

            name = best_place.get("name", "")
            vicinity = best_place.get("vicinity", "Unknown Location")
            geo = best_place.get('geometry', {}).get('location', {})
            dist_km = _haversine_km(latitude, longitude,
                                    geo.get('lat', latitude), geo.get('lng', longitude))
            print(f"Google Places found [{place_type}] {dist_km*1000:.0f} m away: {name} | {vicinity}")
            return name, vicinity

        except Exception as e:
            print(f"Google Places Error ({place_type}): {e}")

    print("Google Places returned no results within range.")
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
                    print(f"Found map page: {result_url}")
                    page_resp = requests.get(result_url, timeout=10,
                                            headers={'User-Agent': 'Mozilla/5.0'})
                    if page_resp.status_code == 200:
                        soup = BeautifulSoup(page_resp.text, 'html.parser')
                        found_maps = []  # COLLECT all maps
                        
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
                            
                            # Skip thumbnails
                            if any(size in src_lower for size in ['-768x', '-300x', '-150x', '-1024x', 'thumbnail']):
                                continue

                            is_map_type = any(k in src_lower or k in alt_text for k in ['map', 'directory', 'floor', 'plan', 'level'])
                            matches_venue = True
                            if venue_keywords:
                                matches_venue = any(k in src_lower or k in alt_text for k in venue_keywords)

                            if not (is_map_type and matches_venue):
                                continue

                            junk = ['menu', 'icon', 'logo', 'button', 'social', 'avatar', 'advert']
                            if any(j in src_lower for j in junk):
                                continue

                            if any(ext in src_lower for ext in ['.jpg', '.jpeg', '.png', '.webp']):
                                if src not in found_maps:  # Avoid duplicates
                                    found_maps.append(src)
                                    print(f"Found map: {src}")
                        
                        if found_maps:
                            print(f"Found {len(found_maps)} map(s)")
                            return found_maps  # Return LIST, not single URL

        except Exception as e:
            print(f"Tavily Search Error: {e}")
            continue

    print(f"No map found for {venue_name}. Check search queries in config.py.")
    return None
