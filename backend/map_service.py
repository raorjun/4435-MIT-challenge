import os
import requests
import re
from bs4 import BeautifulSoup
from config import get_map_search_queries
from urllib.parse import urljoin


def get_venue_context(latitude, longitude):
    url = f"https://nominatim.openstreetmap.org/reverse?lat={latitude}&lon={longitude}&format=json"
    headers = {'User-Agent': 'Steplight Navigation App'}

    try:
        response = requests.get(url, headers=headers, timeout=10)
        data = response.json()
        address = data.get("address", {})

        venue_name = address.get('mall') or address.get('retail') or address.get('commercial')
        address_string = f"{address.get('house_number', '')} {address.get('road', '')}, {address.get('city', '')}".strip()

        return venue_name, address_string
    except Exception as e:
        print(f"Nominatim Error: {e}")
        return None, "Unknown Location"


def find_venue_map(address_string, venue_name=None):
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key:
        print("Error: TAVILY_API_KEY not found.")
        return None

    # Use the specific mall name if we found one, otherwise the street address
    search_term = venue_name if venue_name else address_string
    queries = get_map_search_queries(search_term)

    headers = {"Content-Type": "application/json"}
    url = "https://api.tavily.com/search"

    # Significant words from the venue name to prevent "Piedmont vs Southpoint" mixups
    venue_keywords = []
    if venue_name:
        venue_keywords = [w.lower() for w in venue_name.split() if len(w) > 3]

    for query in queries:
        try:
            payload = {
                "api_key": api_key,
                "query": query,
                "max_results": 5, # Increased results slightly to find better matches
                "include_raw_content": True
            }
            response = requests.post(url, json=payload, headers=headers, timeout=15)

            if response.status_code != 200:
                continue

            data = response.json()
            for result in data.get('results', []):
                result_url = result.get('url', '')

                # 1. Direct file match (High priority)
                if result_url.lower().endswith(('.pdf', '.jpg', '.jpeg', '.png', '.webp')):
                    # Loose check: Ensure the URL doesn't belong to a completely different place
                    if venue_keywords and not any(k in result_url.lower() for k in venue_keywords):
                        continue
                    return result_url

                # 2. Scrape aggregator sites (all-maps, mallseeker, etc.)
                if any(site in result_url for site in ['all-maps.com', 'mallseeker.com', 'mallscenters.com']):
                    page_resp = requests.get(result_url, timeout=10,
                                             headers={'User-Agent': 'Mozilla/5.0'})
                    if page_resp.status_code == 200:
                        soup = BeautifulSoup(page_resp.text, 'html.parser')
                        for img in soup.find_all('img'):
                            src = img.get('src', '')
                            if not src: continue

                            # Fix relative paths
                            if src.startswith('//'):
                                src = 'https:' + src
                            elif not src.startswith('http'):
                                src = urljoin(result_url, src)

                            alt_text = img.get('alt', '').lower()
                            src_lower = src.lower()

                            # Loose Keyword Check: Does this image seem related to our venue?
                            # We check if the image has 'map' OR 'directory' AND matches the venue
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
                                print(f"Found valid map candidate for {venue_name}: {src}")
                                return src

        except Exception as e:
            print(f"Tavily Search Error: {e}")
            continue

    print(f"No map found for {venue_name}. Check search queries in config.py.")
    return None