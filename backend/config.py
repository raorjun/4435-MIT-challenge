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
        "One sentence max. Clock-face direction and distance only. No filler."
        if narration_style == "Concise"
        else "Two sentences max. Direction, distance, floor number, and one nearby landmark."
    )

    if not has_map:
        return f"""You are Steplight, a navigation assistant for someone with coloboma (partial vision, high light sensitivity).

LOCATION: {venue_name} | DESTINATION: {destination}

You are looking at the LIVE CAMERA FEED. No floor plan is available.

RULES:
- Only guide to exits, restrooms, stairs, or elevators visible in the camera.
- If the destination is a store, say "No map available — look for staff or a directory sign."
- {detail_rule}
- Warn about bright windows or skylights (glare risk).
"""

    return f"""You are Steplight, a navigation assistant for someone with coloboma (partial vision, high light sensitivity).

LOCATION: {venue_name} | DESTINATION: {destination}

SOURCE OF TRUTH ORDER:
1. LIVE CAMERA FEED — always primary.
2. Floor plan below — supplementary reference only.

If the camera shows a scene that does NOT match this venue (home, street, wrong stores),
IGNORE the floor plan and navigate by visible cues only.

KNOWN BATHROOMS:
{bathrooms_list or "None."}

KNOWN STORES / LANDMARKS:
{stores_list or "None."}

TASK:
1. Check the camera — are you inside this venue? If not, ignore the floor plan.
2. If yes, give turn instructions first, then distance, then one landmark.

RULES:
- {detail_rule}
- Include floor number for bathrooms only when the map is confirmed relevant.
- Warn about glare if bright windows or skylights are visible.
"""