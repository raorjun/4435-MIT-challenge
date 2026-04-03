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


def get_navigation_prompt(bathrooms_list, stores_list, destination, user_intent,
                          venue_name="", has_map=False):
    has_venue_data = has_map and (bathrooms_list.strip() or stores_list.strip())

    if has_venue_data:
        venue_section = f"""VENUE: {venue_name}

KNOWN BATHROOMS:
{bathrooms_list or 'None identified'}

KNOWN STORES/LANDMARKS:
{stores_list or 'None identified'}"""
        orientation_rule = (
            "2. Cross-reference visible signs with the KNOWN STORES list to orient yourself. "
            "Only mention a store or landmark if you can see it or the list confirms it exists here."
        )
    else:
        venue_section = (
            f"VENUE: {venue_name or 'Unknown — outdoor or single-store location'}\n"
            "No floor plan available. Navigate using only what is visible in the camera."
        )
        orientation_rule = (
            "2. Do NOT invent or guess store names or positions. "
            "Only describe what you can actually see: signage, pathways, entrances, parking, etc."
        )

    return f"""You are Steplight, a navigation assistant for Aditi, who has coloboma and is light-sensitive.
You are looking at her LIVE CAMERA FEED.

{venue_section}

SPOKEN INTENT: {user_intent or 'None'}
DESTINATION: {destination}

TASK:
1. Look at the camera and identify visible landmarks, signs, or pathways.
{orientation_rule}
3. Give ONE clear navigation instruction toward the DESTINATION.

RULES:
- Max 2 sentences. A longer route is fine — do not guess if you are uncertain.
- ALERT her to high-glare areas (skylights, bright windows, direct sun) in the first sentence if present.
- Use clock-face directions (e.g., "at 2 o'clock").
- Give an estimated distance in feet.
- If you cannot determine a confident path, say so and describe what you do see.
"""
