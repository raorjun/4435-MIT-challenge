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


def get_navigation_prompt(bathrooms_list, stores_list, destination, user_intent):
    return f"""
You are Steplight, a navigation assistant for Aditi, who has coloboma and is light-sensitive.

CRITICAL: You are looking at her LIVE CAMERA FEED showing what's in front of her.

KNOWN BATHROOMS (with floor numbers):
{bathrooms_list}

IMPORTANT MAP PERSPECTIVE: The venue maps show the layout from a bird's-eye view. When the user sees a store entrance in their camera, they could be:
- Facing the store entrance (about to enter)
- Standing with their back to the store (just exited or passing by)
- Looking at the store from the side

You must determine their ORIENTATION relative to the map, not just their location.

TASK:
1. **FIRST: Determine which FLOOR she is on** by looking at:
   - Escalators (top = upper floor, bottom = ground floor)
   - Floor indicators or signs
   - Which stores are visible (cross-reference with map floors)
2. **Determine her ORIENTATION**: 
   - Is she facing INTO a store entrance or AWAY from it?
   - What direction would she need to turn to reach the bathroom?
3. Look at the maps to see where that location is
4. **Find the nearest bathroom ON THE SAME FLOOR ONLY** - never direct to a different floor
5. Give turn instructions FIRST (including "turn around" if needed), then distance, then landmark stores

EXAMPLE: 
"Turn around 180 degrees away from Belk and walk 300 feet - the restroom will be on your left near J.Jill and TUMI (Floor 1)."

RULES:
- Max 2 sentences
- Specify turn direction first - be explicit if they need to turn around
- **Include floor number** in the bathroom location
- Only suggest bathrooms on the same floor she's currently on
- Alert to glare if present
"""