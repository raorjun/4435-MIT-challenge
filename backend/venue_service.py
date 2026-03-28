import base64
from typing import Any, Dict, Optional

from map_service import MapServiceError, extract_venue_locations_from_map_urls
from search_service import SearchServiceError, get_address_from_gps, search_for_venue_map_urls
from vision_service import get_spatial_narration


class VenueServiceError(Exception):
    """Raised when venue setup/navigation orchestration fails."""


class NoVenueContextError(VenueServiceError):
    """Raised when navigation is requested before venue setup."""


_venue_cache: Dict[str, Any] = {}


def enter_venue(latitude: float, longitude: float) -> Dict[str, Any]:
    """Resolve current venue, fetch map URLs, and extract structured map anchors."""
    try:
        address = get_address_from_gps(latitude, longitude)
        search_result = search_for_venue_map_urls(address)
        venue_name = str(search_result.get("venue_name") or address)
        map_urls = list(search_result.get("map_urls") or [])
        extracted = extract_venue_locations_from_map_urls(map_urls, venue_name)
    except (SearchServiceError, MapServiceError) as exc:
        raise VenueServiceError(str(exc)) from exc

    venue_context = {
        "address": address,
        "venue_name": venue_name,
        "map_urls": extracted.get("map_urls", map_urls),
        "bathrooms": extracted.get("bathrooms", []),
        "stores": extracted.get("stores", []),
    }

    _venue_cache["current"] = venue_context
    return venue_context


def navigate_in_venue(image_b64: str, destination: str, user_intent: str = "") -> str:
    """Generate navigation narration using camera frame plus cached venue anchors."""
    venue_context = _venue_cache.get("current")
    if not venue_context:
        raise NoVenueContextError("No venue data loaded. Call /venue/enter first")

    try:
        image_bytes = base64.b64decode(image_b64)
    except Exception as exc:
        raise VenueServiceError("Invalid base64 image payload") from exc

    map_context = _format_map_context(venue_context)
    return get_spatial_narration(
        image_bytes=image_bytes,
        destination=destination,
        user_intent=user_intent,
        map_context=map_context,
    )


def get_cached_venue() -> Optional[Dict[str, Any]]:
    return _venue_cache.get("current")


def _format_map_context(venue_context: Dict[str, Any]) -> str:
    bathroom_lines = []
    for bathroom in venue_context.get("bathrooms", []):
        nearest = ", ".join(bathroom.get("nearest_stores", []))
        bathroom_lines.append(
            f"- {bathroom.get('name', 'Restroom')} ({bathroom.get('floor', 'unknown floor')}): "
            f"{bathroom.get('location', 'location unknown')}; near {nearest or 'no landmarks listed'}"
        )

    store_lines = [
        f"- {store.get('name', 'Unknown')}: {store.get('location', 'location unknown')}"
        for store in venue_context.get("stores", [])
    ]

    return (
        f"Venue: {venue_context.get('venue_name', 'Unknown venue')}\n"
        f"Address: {venue_context.get('address', 'Unknown address')}\n"
        "Known Bathrooms:\n"
        f"{chr(10).join(bathroom_lines[:30]) if bathroom_lines else '- none'}\n"
        "Known Stores:\n"
        f"{chr(10).join(store_lines[:50]) if store_lines else '- none'}"
    )

