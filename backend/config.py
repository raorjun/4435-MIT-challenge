def get_map_search_queries(venue_name):
    return [
        f"{venue_name} map site:all-maps.com",
        f"{venue_name} directory site:mallseeker.com",
        f"{venue_name} mall directory map PDF",
        f"{venue_name} floor plan",
        f"{venue_name} map site:pinterest.com"
    ]


EXTRACTION_PROMPT = """
Analyze this venue directory/map and extract navigation information.
This could be a mall, airport, hospital, campus, or outdoor complex.

CRITICAL: For each bathroom/restroom, identify the SPECIFIC LOCATIONS it is near.

1. BATHROOMS/RESTROOMS:
   - Name/label (e.g., "Restroom", "Family Restroom")
   - Floor/level if shown
   - NEAREST LOCATIONS: List 2-3 specific stores/landmarks closest to this bathroom.

2. MAJOR LOCATIONS (stores, gates, major signs)
   - List up to 40 major anchor points.

Return ONLY valid JSON:
{
  "bathrooms": [
    {"name": "Restroom", "floor": "1", "nearest_stores": ["Apple", "Gate A12"], "location": "near Apple Store"}
  ],
  "stores": [
    {"name": "Apple", "location": "North Wing"}
  ]
}
"""


def get_navigation_prompt(bathrooms_list, stores_list, destination, user_intent):
    return f"""
You are Steplight, a navigation assistant for Aditi, who has coloboma and is light-sensitive.
You are looking at her LIVE CAMERA FEED.

KNOWN BATHROOMS IN THIS VENUE:
{bathrooms_list}

KNOWN STORES/LANDMARKS IN THIS VENUE:
{stores_list}

SPOKEN INTENT: {user_intent or 'None'}
DESTINATION: {destination}

TASK:
1. Look at the camera view and identify visible stores/signs.
2. Cross-reference what you see with the KNOWN STORES list to orient yourself.
3. Calculate the route toward the DESTINATION.
4. Give ONE clear navigation instruction.

RULES:
- Max 2 sentences.
- ALERT her to high-glare areas (skylights, bright windows) in the first sentence.
- Use clock-face directions (e.g., "at 2 o'clock").
- Give an estimated distance in feet.
"""
