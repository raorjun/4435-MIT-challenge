def get_map_search_queries(venue_name, city_hint=""):
    """Build search queries for a venue map/directory.

    city_hint should be the city (and ideally state) string extracted from the
    Google Places vicinity field — e.g. "Durham, NC".  Quoting the venue name
    and appending the city makes Tavily much less likely to return maps for a
    same-named venue in a different city (e.g. a Vegas mall instead of NC).
    """
    loc = f" {city_hint}" if city_hint else ""
    quoted = f'"{venue_name}"'
    return [
        f"{quoted}{loc} map site:all-maps.com",
        f"{quoted}{loc} directory site:mallseeker.com",
        f"{quoted}{loc} mall directory map PDF",
        f"{quoted}{loc} floor plan",
        f"{quoted}{loc} map site:pinterest.com",
    ]


EXTRACTION_PROMPT = """
Analyze this venue directory/map and extract navigation information.
This could be a mall, airport, hospital, campus, or outdoor complex.

IMPORTANT: 
- If the map shows multiple floors in one image, extract bathrooms from ALL floors shown
- Look for a LEGEND or KEY that shows what bathroom/restroom symbols look like
- Bathroom symbols are typically marked in the legend with labels like "RESTROOM", "PUBLIC RESTROOM", or similar
- Do NOT mistake entrance numbers (1A, 2B), parking markers, or deck labels for bathroom locations

CRITICAL: For each bathroom/restroom, identify the SPECIFIC LOCATIONS it is near.

1. BATHROOMS/RESTROOMS:
   - First check if there is a legend/key showing what restroom symbols look like
   - Look for those exact symbols throughout the entire map
   - Name/label (e.g., "Restroom", "Family Restroom")
   - Floor/level (if map shows "UPPER LEVEL" and "LOWER LEVEL", note which one)
   - NEAREST LOCATIONS: List 2-3 specific store names closest to this bathroom

2. MAJOR LOCATIONS (stores, gates, major signs)
   - List up to 40 major anchor points with their floor if shown

Return ONLY valid JSON:
{
  "bathrooms": [
    {"name": "Restroom", "floor": "1", "nearest_stores": ["Apple", "Gate A12"], "location": "near Apple Store"}
  ],
  "stores": [
    {"name": "Apple", "location": "North Wing", "floor": "1"}
  ]
}
"""


def get_navigation_prompt(bathrooms_list, stores_list, destination,
                          venue_name="this location", has_map=False,
                          narration_style="Concise"):
    detail_rule = (
        "One sentence. Clock-face direction and distance only."
        if narration_style == "Concise"
        else "Two sentences. Direction, distance, and one visible landmark."
    )

    if not has_map:
        return f"""You are a navigation assistant for someone with partial vision (coloboma — sensitive to bright light).

The user wants to reach: {destination}

Look at the live camera image and tell them exactly how to get there based on what you can see right now.
Use clock-face directions (e.g. "at 10 o'clock, turn left").
If {destination} is not visible yet, describe what you DO see and which direction to move to find it.
Never suggest going to an exit or asking for staff unless the user specifically asked for that.
{detail_rule}
If you see a bright window or light source directly ahead, warn them.
"""

    return f"""You are a navigation assistant for someone with partial vision (coloboma — sensitive to bright light).

The user is inside {venue_name} and wants to reach: {destination}

Look at the live camera image first. If the scene matches this venue, use the reference list below.
If the camera shows a home, street, or unrecognized space, ignore the list and navigate by what you see.

BATHROOMS: {bathrooms_list or "None."}
STORES / LANDMARKS: {stores_list or "None."}

Tell them how to reach {destination} based on what the camera shows.
Give the turn direction first, then distance, then one visible landmark.
{detail_rule}
If you see a bright window or light source directly ahead, warn them.
"""