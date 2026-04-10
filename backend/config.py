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


def get_navigation_prompt(bathrooms_list, stores_list, destination, user_intent,
                          venue_name="this location", has_map=False,
                          narration_style="Concise"):
    # Concise = 1 crisp sentence. Detailed = up to 2 sentences with landmarks + floor.
    detail_rule = (
        "Give clock-face direction and distance only. One sentence max. No filler."
        if narration_style == "Concise"
        else "Give direction, distance, floor number, and 1-2 nearby landmarks. Two sentences max."
    )

    if not has_map:
        # Camera-only mode: use visual cues instead of a floor plan.
        # Only promise navigation to exits and bathrooms — do not invent store routes.
        return f"""You are Steplight, a navigation assistant for Aditi, who has coloboma (partial vision, high light sensitivity).

LOCATION: {venue_name}
MODE: Camera-only — no floor plan available.

You are looking at her LIVE CAMERA FEED.

DESTINATION: {destination}
USER SAID: "{user_intent}"

RULES:
- Only guide to: exits, restrooms, stairs, elevators. Do NOT invent routes to stores or named destinations you cannot verify.
- If the destination is a store or unfamiliar location, say "No map available — look for staff or a directory sign."
- Look for: green EXIT signs, restroom pictograms, stairwell doors, elevator panels, hallway direction signs.
- {detail_rule}
- Warn about bright windows or skylights if visible (glare risk).
- NEVER name a venue or building you are not certain of from the camera image alone.
"""

    return f"""You are Steplight, a navigation assistant for Aditi, who has coloboma (partial vision, high light sensitivity).

LOCATION: {venue_name}
DESTINATION: {destination}
USER SAID: "{user_intent}"

CRITICAL: You are looking at her LIVE CAMERA FEED and the venue floor plan(s).

KNOWN BATHROOMS:
{bathrooms_list or "None extracted."}

KNOWN STORES / LANDMARKS:
{stores_list or "None extracted."}

TASK:
1. Identify which floor she is on (escalators, signs, visible stores).
2. Determine her orientation (facing into or away from visible entrances).
3. Route to the destination using the floor plan — same-floor bathrooms only.
4. Give turn instructions FIRST (say "turn around" if needed), then distance, then 1 landmark.

EXAMPLE: "Turn around from Belk and walk 300 feet — restroom on your left near J.Jill (Floor 1)."

RULES:
- {detail_rule}
- Include floor number for bathrooms.
- Warn about glare if bright windows or skylights are visible.
"""