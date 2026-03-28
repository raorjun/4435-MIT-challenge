"""
Flask Backend Integration - Map-Based Navigation
Uses web_search to automatically find venue maps
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import base64
import json
from google import genai
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

client = genai.Client(api_key=os.getenv('GOOGLE_API_KEY'))

# Cache for venue data
venue_cache = {}
identified_mall_name = None  # Global to store identified mall name


def get_address_from_gps(latitude, longitude):
    """Get address from GPS coordinates"""
    import requests
    
    url = f"https://nominatim.openstreetmap.org/reverse?lat={latitude}&lon={longitude}&format=json"
    headers = {'User-Agent': 'Steplight Navigation App'}
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        data = response.json()
        
        address = data.get('address', {})
        house_number = address.get('house_number', '')
        road = address.get('road', '')
        city = address.get('city', '')
        
        address_string = f"{house_number} {road}, {city}".strip()
        print(f"Address: {address_string}")
        return address_string
        
    except Exception as e:
        print(f"Error getting address: {e}")
        return "Unknown Location"


def search_for_venue_map_url(address_string):
    """
    Use Tavily API (free web search for AI) to find mall map
    """
    print(f"Using Tavily to find map for: {address_string}")
    
    TAVILY_API_KEY = os.getenv('TAVILY_API_KEY')
    
    if not TAVILY_API_KEY:
        print("ERROR: TAVILY_API_KEY not set in .env")
        print("Get one at: https://tavily.com")
        return None
    
    try:
        import requests
        
        # Tavily search API endpoint
        url = "https://api.tavily.com/search"
        
        headers = {
            "Content-Type": "application/json"
        }
        
        # Step 1: Find the mall name
        payload = {
            "api_key": TAVILY_API_KEY,
            "query": f"{address_string} location name",
            "max_results": 3
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        
        if response.status_code != 200:
            print(f"Tavily API error: {response.status_code}")
            return None
        
        data = response.json()
        
        # Extract mall name from results
        mall_name = None
        for result in data.get('results', []):
            content = result.get('content', '').lower()
            if 'southpoint' in content or 'streets at southpoint' in content:
                mall_name = "The Streets at Southpoint"
                break
        
        if not mall_name:
            # Try to extract from first result
            first_title = data.get('results', [{}])[0].get('title', '')
            mall_name = first_title.split('-')[0].strip() if first_title else "mall"
        
        print(f"Identified mall: {mall_name}")
        
        # Store globally for filtering later
        global identified_mall_name
        identified_mall_name = mall_name
        
        # Step 2: Search for map on aggregator sites
        search_queries = [
            f"{mall_name} map site:all-maps.com",
            f"{mall_name} directory site:mallseeker.com",
            f"{mall_name} mall directory map PDF",
            f"{mall_name} floor plan"
            f"{mall_name} map site:pinterest.com"
        ]
        
        for query in search_queries:
            print(f"Searching: {query}")
            
            payload = {
                "api_key": TAVILY_API_KEY,
                "query": query,
                "max_results": 5,
                "include_raw_content": True
            }
            
            response = requests.post(url, json=payload, headers=headers, timeout=15)
            
            if response.status_code != 200:
                continue
            
            data = response.json()
            
            # Look for map URLs in results
            for result in data.get('results', []):
                result_url = result.get('url', '')
                content = result.get('content', '').lower()
                raw_content = result.get('raw_content', '')
                
                # Check if this page has a map
                if 'all-maps.com' in result_url or 'mallseeker.com' in result_url:
                    print(f"Found map page: {result_url}")
                    
                    # Actually fetch the page to extract images
                    try:
                        page_response = requests.get(result_url, timeout=10, headers={
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                        })
                        
                        if page_response.status_code == 200:
                            page_html = page_response.text
                            
                            # Extract ALL map image URLs from the page
                            import re
                            from bs4 import BeautifulSoup
                            
                            soup = BeautifulSoup(page_html, 'html.parser')
                            
                            map_candidates = []
                            
                            # Find all img tags
                            all_imgs = soup.find_all('img')
                            print(f"  Found {len(all_imgs)} total images on page")
                            
                            for img in all_imgs:
                                src = img.get('src', '')
                                alt = img.get('alt', '').lower()
                                
                                # Skip thumbnails (have dimensions in URL like 768x, 300x, 150x)
                                if any(size in src.lower() for size in ['-768x', '-300x', '-150x', '-1024x', 'thumbnail']):
                                    continue
                                
                                # Look for map-related images
                                if any(keyword in src.lower() or keyword in alt for keyword in ['map', 'directory', 'floor', 'plan', 'level']):
                                    # Make URL absolute
                                    if src.startswith('//'):
                                        src = 'https:' + src
                                    elif src.startswith('/'):
                                        from urllib.parse import urljoin
                                        src = urljoin(result_url, src)
                                    
                                    # Skip obvious non-maps
                                    skip_patterns = ['/logo', '/icon', '/avatar', '/banner', '/ad/', 'gravatar']
                                    if any(skip in src.lower() for skip in skip_patterns):
                                        continue
                                    
                                    if src.startswith('http') and any(ext in src.lower() for ext in ['.jpg', '.jpeg', '.png', '.webp', '.pdf']):
                                        if src not in map_candidates:
                                            map_candidates.append(src)
                                            print(f"    Found candidate: {src}")
                            
                            print(f"  Found {len(map_candidates)} candidate images")
                            
                            # Now filter by actual file size - real maps are large (>50KB typically)
                            map_images = []
                            for candidate_url in map_candidates:
                                try:
                                    # HEAD request to get file size without downloading
                                    head_response = requests.head(candidate_url, timeout=5, headers={
                                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                                    })
                                    
                                    content_length = head_response.headers.get('Content-Length')
                                    if content_length:
                                        size_kb = int(content_length) / 1024
                                        
                                        # Real mall maps are usually 50KB+
                                        if size_kb > 50:
                                            map_images.append(candidate_url)
                                            print(f"  ✓ Map: {candidate_url} ({size_kb:.0f}KB)")
                                        else:
                                            print(f"  ✗ Too small: {candidate_url} ({size_kb:.0f}KB)")
                                except Exception as e:
                                    # If HEAD fails, include it anyway
                                    print(f"  ? Couldn't check size for {candidate_url}, including anyway")
                                    map_images.append(candidate_url)
                            
                            if map_images:
                                print(f"[SUCCESS] Found {len(map_images)} map image(s)")
                                return map_images  # Return list of URLs
                            
                            print(f"  No map images found in page content")
                    
                    except Exception as e:
                        print(f"  Error fetching page: {e}")
                    
                    # Try to extract from raw_content if fetch failed
                    import re
                    img_patterns = [
                        r'<img[^>]+src=["\']([^"\']+map[^"\']+)["\']',
                        r'<img[^>]+src=["\']([^"\']+directory[^"\']+)["\']',
                        r'https?://[^\s<>"]+map[^\s<>"]*\.(?:jpg|jpeg|png|pdf)',
                    ]
                    
                    for pattern in img_patterns:
                        matches = re.findall(pattern, raw_content, re.IGNORECASE)
                        if matches:
                            map_url = matches[0]
                            if not map_url.startswith('http'):
                                from urllib.parse import urljoin
                                map_url = urljoin(result_url, map_url)
                            print(f"[SUCCESS] Found map in raw content: {map_url}")
                            return map_url
                
                # Check for direct PDF/image links
                if result_url.endswith(('.pdf', '.jpg', '.jpeg', '.png')):
                    if any(keyword in result_url.lower() for keyword in ['map', 'directory', 'floor']):
                        print(f"[SUCCESS] Found direct map file: {result_url}")
                        return result_url
        
        print("No map found after searching")
        return None
        
    except Exception as e:
        print(f"Error using Tavily: {e}")
        import traceback
        traceback.print_exc()
        return None


def extract_bathroom_locations_from_url(map_urls, mall_name=""):
    """Download map(s) and send to Gemini to extract bathroom locations"""
    
    # Handle single URL or list
    if isinstance(map_urls, str):
        map_urls = [map_urls]
    
    # Remove duplicates
    map_urls = list(dict.fromkeys(map_urls))
    
    # Filter to only maps matching the mall name
    if mall_name:
        # Extract key words from mall name for matching
        # Remove common words and split
        mall_keywords = []
        clean_name = mall_name.lower()
        # Remove common words
        for word in ['the', 'at', 'mall', 'center', 'plaza', 'shopping']:
            clean_name = clean_name.replace(f' {word} ', ' ').replace(f'{word} ', '').replace(f' {word}', '')
        
        # Split and get significant words (>3 chars)
        mall_keywords = [w for w in clean_name.split() if len(w) > 3]
        
        print(f"Looking for maps with keywords: {mall_keywords}")
        
        filtered_urls = []
        for url in map_urls:
            url_lower = url.lower()
            # Check if URL contains any mall-specific keywords
            if any(keyword in url_lower for keyword in mall_keywords):
                filtered_urls.append(url)
                print(f"  Kept: {url} (matches {[k for k in mall_keywords if k in url_lower]})")
            else:
                print(f"  Skipped: {url}")
        
        if filtered_urls:
            map_urls = filtered_urls
            print(f"Filtered to {len(map_urls)} relevant map(s)")
    
    print(f"Extracting from {len(map_urls)} map(s)")
    
    all_bathrooms = []
    all_stores = []
    
    for map_url in map_urls:
        print(f"\nProcessing: {map_url}")
        
        # Download the image
        try:
            import requests
            download_response = requests.get(map_url, timeout=30)
            
            if download_response.status_code != 200:
                print(f"Failed to download: {download_response.status_code}")
                continue
            
            map_bytes = download_response.content
            
            # Determine MIME type
            if map_url.endswith('.pdf'):
                mime_type = 'application/pdf'
            elif map_url.endswith('.webp'):
                mime_type = 'image/webp'
            elif map_url.endswith('.png'):
                mime_type = 'image/png'
            elif map_url.endswith('.jpg') or map_url.endswith('.jpeg'):
                mime_type = 'image/jpeg'
            else:
                mime_type = 'image/jpeg'
            
            print(f"Downloaded ({len(map_bytes)} bytes)")
            
        except Exception as e:
            print(f"Error downloading: {e}")
            continue
        
        prompt = """
        Analyze this venue directory/map and extract navigation information.
        This could be a mall, airport, hospital, campus, or other public space.
        
        CRITICAL: For each bathroom/restroom, identify the SPECIFIC LOCATIONS it is near.
        
        1. BATHROOMS/RESTROOMS:
           - Name/label (e.g., "Restroom", "Family Restroom", "Men's/Women's Room")
           - Floor/level if shown
           - NEAREST LOCATIONS: List 2-3 specific stores/landmarks/room names closest to this bathroom
           - Location description
        
        2. MAJOR LOCATIONS (stores, offices, gates, departments, room numbers, etc.)
        
        Return ONLY valid JSON:
        {
          "bathrooms": [
            {
              "name": "Restroom",
              "floor": "1",
              "nearest_stores": ["Apple", "Gate A12"],
              "location": "near Apple Store"
            }
          ],
          "stores": [
            {"name": "Apple", "location": "west"}
          ]
        }
        """
        
        try:
            from google.genai import types
            
            response = client.models.generate_content(
                model='gemini-3.1-flash-lite-preview',
                contents=[
                    types.Part.from_bytes(data=map_bytes, mime_type=mime_type),
                    prompt
                ]
            )
            
            text = response.text.strip()
            if text.startswith('```json'):
                text = text[7:]
            if text.startswith('```'):
                text = text[3:]
            if text.endswith('```'):
                text = text[:-3]
            text = text.strip()
            
            data = json.loads(text)
            
            all_bathrooms.extend(data.get('bathrooms', []))
            all_stores.extend(data.get('stores', []))
            
            print(f"Found: {len(data.get('bathrooms', []))} bathrooms")
            for b in data.get('bathrooms', []):
                stores = ', '.join(b.get('nearest_stores', []))
                print(f"  - {b.get('name', 'Restroom')} near: {stores}")
            
        except Exception as e:
            print(f"Error extracting: {e}")
            continue
    
    if not all_bathrooms:
        return None
    
    print(f"\nTOTAL: {len(all_bathrooms)} bathrooms, {len(all_stores)} stores")
    
    return {
        'bathrooms': all_bathrooms,
        'stores': all_stores
    }


@app.route('/enter_venue', methods=['POST'])
def enter_venue():
    """
    Called when user enters a venue
    Automatically finds venue map URL
    """
    data = request.json
    lat = data['latitude']
    lon = data['longitude']
    
    print(f"\n{'='*60}")
    print(f"USER ENTERED VENUE")
    print(f"{'='*60}")
    
    # Step 1: Get address
    address = get_address_from_gps(lat, lon)
    
    # Step 2: Search for map URL (uses web_search tool)
    map_url = search_for_venue_map_url(address)
    
    if not map_url:
        return jsonify({
            'success': False,
            'message': 'No map found for this venue'
        })
    
    # Step 3: Extract bathroom locations from map URL
    # Use the mall name that Tavily identified (stored globally)
    venue_info = extract_bathroom_locations_from_url(map_url, identified_mall_name or address)
    
    if not venue_info:
        return jsonify({
            'success': False,
            'message': 'Failed to extract venue data'
        })
    
    # Step 4: Cache map URL for navigation
    venue_info['map_url'] = map_url
    venue_info['address'] = address
    
    venue_cache['current'] = venue_info
    
    return jsonify({
        'success': True,
        'venue': address,
        'bathrooms_found': len(venue_info.get('bathrooms', [])),
        'stores_found': len(venue_info.get('stores', []))
    })


@app.route('/navigate', methods=['POST'])
def navigate():
    """
    Navigate using camera + map
    """
    data = request.json
    image_b64 = data['image']
    destination = data['destination']
    
    venue_data = venue_cache.get('current')
    
    if not venue_data:
        return jsonify({'error': 'No venue data loaded. Call /enter_venue first'}), 400
    
    # Build context from cached bathroom data
    bathrooms_list = "\n".join([
        f"- {b['name']}: {b['location']}" 
        for b in venue_data.get('bathrooms', [])
    ])
    
    stores_list = "\n".join([
        f"- {s['name']}: {s['location']}"
        for s in venue_data.get('stores', [])
    ])
    
    prompt = f"""
    You are helping a visually impaired person navigate inside a mall.
    
    AVAILABLE INFORMATION:
    
    1. MALL MAP (image provided): Shows full layout, stores, bathrooms
    
    2. USER'S CAMERA VIEW (image provided): What they see right now
    
    3. KNOWN BATHROOMS:
    {bathrooms_list}
    
    4. KNOWN STORES:
    {stores_list}
    
    TASK:
    
    Step 1: Look at camera view and identify visible stores/landmarks
    Step 2: Match these to locations on the mall map
    Step 3: Find nearest {destination} on the map
    Step 4: Give ONE clear navigation instruction (max 2 sentences)
    
    Example: "Turn right and walk toward Barnes & Noble. The bathroom is just past it on your left, about 150 feet away."
    """
    
    try:
        from google.genai import types
        import base64
        import requests
        
        # Decode user's camera image
        camera_bytes = base64.b64decode(image_b64)
        
        # Download the first map image (we'll use Level 1 for now)
        map_urls = venue_data.get('map_url', [])
        if isinstance(map_urls, str):
            map_urls = [map_urls]
        
        if not map_urls:
            return jsonify({'error': 'No map URL in cache'}), 500
        
        # Use first map
        map_url = map_urls[0]
        map_response = requests.get(map_url, timeout=30)
        
        if map_response.status_code != 200:
            return jsonify({'error': 'Failed to download map'}), 500
        
        map_bytes = map_response.content
        
        # Determine map MIME type
        if map_url.endswith('.webp'):
            map_mime = 'image/webp'
        elif map_url.endswith('.png'):
            map_mime = 'image/png'
        elif map_url.endswith('.jpg') or map_url.endswith('.jpeg'):
            map_mime = 'image/jpeg'
        elif map_url.endswith('.pdf'):
            map_mime = 'application/pdf'
        else:
            map_mime = 'image/jpeg'
        
        # Send both camera image and map to Gemini
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[
                types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg'),
                types.Part.from_bytes(data=map_bytes, mime_type=map_mime),
                prompt
            ]
        )
        
        return jsonify({'narration': response.text.strip()})
        
    except Exception as e:
        print(f"Navigation error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/navigate_with_file', methods=['POST'])
def navigate_with_file():
    """
    Navigate using an image file from disk
    """
    data = request.json
    image_path = data.get('image_path', 'test_image.jpg')  # Path relative to backend folder
    destination = data.get('destination', 'bathroom')
    
    venue_data = venue_cache.get('current')
    
    if not venue_data:
        return jsonify({'error': 'No venue data loaded. Call /enter_venue first'}), 400
    
    # Load image from file
    import os
    if not os.path.exists(image_path):
        return jsonify({'error': f'Image file not found: {image_path}'}), 400
    
    with open(image_path, 'rb') as f:
        camera_bytes = f.read()
    
    print(f"Loaded test image from {image_path} ({len(camera_bytes)} bytes)")
    
    # Build context
    bathrooms_list = "\n".join([
        f"- {b.get('name', 'Restroom')}: near {', '.join(b.get('nearest_stores', []))}" 
        for b in venue_data.get('bathrooms', [])
    ])
    
    stores_list = "\n".join([
        f"- {s['name']}: {s.get('location', '')}"
        for s in venue_data.get('stores', [])[:20]  # First 20 stores
    ])
    
    prompt = f"""
    You are helping a visually impaired person navigate inside a public venue (mall, airport, hospital, campus, etc.).
    
    AVAILABLE INFORMATION:
    
    1. VENUE MAP (image provided below): Shows full layout, stores/locations, bathrooms
    
    2. USER'S CAMERA VIEW (image provided): What they see right now - identify visible stores/signs/landmarks
    
    3. KNOWN BATHROOMS/RESTROOMS:
    {bathrooms_list}
    
    4. SOME KNOWN LOCATIONS:
    {stores_list}
    
    TASK:
    
    Step 1: Look at the camera image - what landmarks, stores, or signs can you see?
    Step 2: Look at the venue map - where is that location on the map?
    Step 3: Find the nearest {destination} on the map
    Step 4: Give ONE clear navigation instruction (max 2 sentences with distance in feet)
    
    Be specific about direction (turn left/right, walk straight) and include approximate distance.
    
    Example: "I see you're near the Apple Store entrance. Turn right and walk 150 feet - the restroom will be on your left, just past Barnes & Noble."
    """
    
    try:
        from google.genai import types
        import requests
        
        # Download the first map
        map_urls = venue_data.get('map_url', [])
        if isinstance(map_urls, str):
            map_urls = [map_urls]
        
        if not map_urls:
            return jsonify({'error': 'No map URL in cache'}), 500
        
        map_url = map_urls[0]
        print(f"Downloading map: {map_url}")
        map_response = requests.get(map_url, timeout=30)
        
        if map_response.status_code != 200:
            return jsonify({'error': 'Failed to download map'}), 500
        
        map_bytes = map_response.content
        print(f"Map downloaded ({len(map_bytes)} bytes)")
        
        # Determine MIME types
        if map_url.endswith('.webp'):
            map_mime = 'image/webp'
        elif map_url.endswith('.png'):
            map_mime = 'image/png'
        else:
            map_mime = 'image/jpeg'
        
        camera_mime = 'image/jpeg' if image_path.endswith('.jpg') or image_path.endswith('.jpeg') else 'image/png'
        
        print("Sending to Gemini...")
        # Send both images to Gemini
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[
                types.Part.from_bytes(data=camera_bytes, mime_type=camera_mime),
                types.Part.from_bytes(data=map_bytes, mime_type=map_mime),
                prompt
            ]
        )
        
        narration = response.text.strip()
        print(f"Gemini response: {narration}")
        
        return jsonify({
            'narration': narration,
            'image_used': image_path
        })
        
    except Exception as e:
        print(f"Navigation error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

def navigate():
    """
    Navigate using camera + map
    """
    data = request.json
    image_b64 = data['image']
    destination = data['destination']
    
    venue_data = venue_cache.get('current')
    
    if not venue_data:
        return jsonify({'error': 'No venue data loaded. Call /enter_venue first'}), 400
    
    # Build context from cached bathroom data
    bathrooms_list = "\n".join([
        f"- {b['name']}: {b['location']}" 
        for b in venue_data.get('bathrooms', [])
    ])
    
    stores_list = "\n".join([
        f"- {s['name']}: {s['location']}"
        for s in venue_data.get('stores', [])
    ])
    
    prompt = f"""
    You are helping a visually impaired person navigate inside a mall.
    
    AVAILABLE INFORMATION:
    
    1. MALL MAP (image provided): Shows full layout, stores, bathrooms
    
    2. USER'S CAMERA VIEW (image provided): What they see right now
    
    3. KNOWN BATHROOMS:
    {bathrooms_list}
    
    4. KNOWN STORES:
    {stores_list}
    
    TASK:
    
    Step 1: Look at camera view and identify visible stores/landmarks
    Step 2: Match these to locations on the mall map
    Step 3: Find nearest {destination} on the map
    Step 4: Give ONE clear navigation instruction (max 2 sentences)
    
    Example: "Turn right and walk toward Barnes & Noble. The bathroom is just past it on your left, about 150 feet away."
    """
    
    try:
        from google.genai import types
        import base64
        import requests
        
        # Decode user's camera image
        camera_bytes = base64.b64decode(image_b64)
        
        # Download the map image
        map_url = venue_data['map_url']
        map_response = requests.get(map_url, timeout=30)
        
        if map_response.status_code != 200:
            return jsonify({'error': 'Failed to download map'}), 500
        
        map_bytes = map_response.content
        
        # Determine map MIME type
        if map_url.endswith('.webp'):
            map_mime = 'image/webp'
        elif map_url.endswith('.png'):
            map_mime = 'image/png'
        elif map_url.endswith('.jpg') or map_url.endswith('.jpeg'):
            map_mime = 'image/jpeg'
        elif map_url.endswith('.pdf'):
            map_mime = 'application/pdf'
        else:
            map_mime = 'image/jpeg'
        
        # Send both camera image and map to Gemini
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[
                types.Part.from_bytes(data=camera_bytes, mime_type='image/jpeg'),
                types.Part.from_bytes(data=map_bytes, mime_type=map_mime),
                prompt
            ]
        )
        
        return jsonify({'narration': response.text.strip()})
        
    except Exception as e:
        print(f"Navigation error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print('Starting Map-Based Navigation Backend on port 5001...')
    app.run(host='0.0.0.0', port=5001, debug=True)