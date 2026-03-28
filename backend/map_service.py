import os
import requests
import re
from bs4 import BeautifulSoup
from config import get_map_search_queries


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
        return None

    search_term = venue_name if venue_name else address_string
    queries = get_map_search_queries(search_term)

    headers = {"Content-Type": "application/json"}
    url = "https://api.tavily.com/search"
    for query in queries:
        try:
            payload = {"api_key": api_key, "query": query, "max_results": 3,
                       "include_raw_content": True}
            response = requests.post(url, json=payload, headers=headers, timeout=15)

            if response.status_code != 200:
                continue

            data = response.json()
            for result in data.get('results', []):
                result_url = result.get('url', '')

                # Direct file match
                if result_url.endswith(('.pdf', '.jpg', '.jpeg', '.png')):
                    return result_url

                # Scrape aggregator sites
                if 'all-maps.com' in result_url or 'mallseeker.com' in result_url:
                    page_resp = requests.get(result_url, timeout=10,
                                             headers={'User-Agent': 'Mozilla/5.0'})
                    if page_resp.status_code == 200:
                        soup = BeautifulSoup(page_resp.text, 'html.parser')
                        for img in soup.find_all('img'):
                            src = img.get('src', '')
                            # Filter out thumbnails and icons
                            if any(size in src.lower() for size in
                                   ['-150x', 'thumbnail', '/logo', '/icon']):
                                continue
                            if any(ext in src.lower() for ext in ['.jpg', '.jpeg', '.png']):
                                if src.startswith('//'): src = 'https:' + src
                                return src
        except Exception as e:
            print(f"Tavily Search Error: {e}")
            continue

    return None
