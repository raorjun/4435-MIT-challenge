import re
from typing import Dict, List
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import os

load_dotenv()


class SearchServiceError(Exception):
    """Raised when venue/map search fails."""


def get_address_from_gps(latitude: float, longitude: float) -> str:
    """Reverse-geocode coordinates using Nominatim for a human-readable venue hint."""
    url = "https://nominatim.openstreetmap.org/reverse"
    params = {"lat": latitude, "lon": longitude, "format": "json"}
    headers = {"User-Agent": "Steplight Navigation App"}

    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
    except Exception as exc:
        raise SearchServiceError(f"Failed to reverse-geocode location: {exc}") from exc

    address = data.get("address", {})
    house_number = address.get("house_number", "")
    road = address.get("road", "")
    city = address.get("city") or address.get("town") or address.get("village") or ""

    address_string = f"{house_number} {road}, {city}".strip(" ,")
    return address_string or "Unknown Location"


def search_for_venue_map_urls(address_string: str) -> Dict[str, object]:
    """Use Tavily search + page scraping to locate candidate map URLs for a venue."""
    tavily_api_key = os.getenv("TAVILY_API_KEY")
    if not tavily_api_key:
        raise SearchServiceError("TAVILY_API_KEY is not configured")

    search_url = "https://api.tavily.com/search"
    headers = {"Content-Type": "application/json"}

    venue_name = _infer_venue_name(address_string, tavily_api_key, search_url, headers)

    search_queries = [
        f"{venue_name} map site:all-maps.com",
        f"{venue_name} directory site:mallseeker.com",
        f"{venue_name} mall directory map PDF",
        f"{venue_name} floor plan",
        f"{venue_name} map site:pinterest.com",
    ]

    discovered_urls: List[str] = []
    for query in search_queries:
        payload = {
            "api_key": tavily_api_key,
            "query": query,
            "max_results": 5,
            "include_raw_content": True,
        }
        try:
            response = requests.post(search_url, json=payload, headers=headers, timeout=15)
            response.raise_for_status()
        except Exception:
            continue

        data = response.json()
        for result in data.get("results", []):
            result_url = result.get("url", "")
            raw_content = result.get("raw_content", "")

            if _is_direct_map_url(result_url):
                discovered_urls.append(result_url)

            if "all-maps.com" in result_url or "mallseeker.com" in result_url:
                discovered_urls.extend(_extract_map_urls_from_result_page(result_url, raw_content))

    unique_urls = list(dict.fromkeys(url for url in discovered_urls if url))
    if not unique_urls:
        raise SearchServiceError("No candidate map URLs found for the venue")

    return {
        "venue_name": venue_name,
        "map_urls": unique_urls,
    }


def _infer_venue_name(address_string: str, api_key: str, url: str, headers: Dict[str, str]) -> str:
    payload = {
        "api_key": api_key,
        "query": f"{address_string} location name",
        "max_results": 3,
    }

    try:
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        response.raise_for_status()
        data = response.json()
    except Exception as exc:
        raise SearchServiceError(f"Failed to infer venue name: {exc}") from exc

    for result in data.get("results", []):
        content = result.get("content", "").lower()
        if "southpoint" in content or "streets at southpoint" in content:
            return "The Streets at Southpoint"

    first_title = data.get("results", [{}])[0].get("title", "")
    return first_title.split("-")[0].strip() if first_title else "mall"


def _extract_map_urls_from_result_page(result_url: str, raw_content: str) -> List[str]:
    try:
        page_response = requests.get(
            result_url,
            timeout=10,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        page_response.raise_for_status()
        map_candidates = _extract_map_candidates_from_html(page_response.text, result_url)
        if map_candidates:
            return map_candidates
    except Exception:
        pass

    return _extract_map_candidates_from_raw_content(raw_content, result_url)


def _extract_map_candidates_from_html(html: str, base_url: str) -> List[str]:
    soup = BeautifulSoup(html, "html.parser")
    map_candidates: List[str] = []

    for img in soup.find_all("img"):
        src = (img.get("src") or "").strip()
        alt = (img.get("alt") or "").lower()

        if not src:
            continue
        if any(size in src.lower() for size in ["-768x", "-300x", "-150x", "-1024x", "thumbnail"]):
            continue
        if any(skip in src.lower() for skip in ["/logo", "/icon", "/avatar", "/banner", "/ad/", "gravatar"]):
            continue

        src_lower = src.lower()
        if not any(keyword in src_lower or keyword in alt for keyword in ["map", "directory", "floor", "plan", "level"]):
            continue

        if src.startswith("//"):
            src = "https:" + src
        elif src.startswith("/"):
            src = urljoin(base_url, src)

        if src.startswith("http") and any(ext in src_lower for ext in [".jpg", ".jpeg", ".png", ".webp", ".pdf"]):
            map_candidates.append(src)

    return _filter_candidates_by_file_size(map_candidates)


def _extract_map_candidates_from_raw_content(raw_content: str, base_url: str) -> List[str]:
    patterns = [
        r"<img[^>]+src=[\"']([^\"']+map[^\"']+)[\"']",
        r"<img[^>]+src=[\"']([^\"']+directory[^\"']+)[\"']",
        r"https?://[^\s<>"]+map[^\s<>"]*\.(?:jpg|jpeg|png|pdf)",
    ]

    map_urls: List[str] = []
    for pattern in patterns:
        for match in re.findall(pattern, raw_content or "", re.IGNORECASE):
            url = urljoin(base_url, match) if not match.startswith("http") else match
            map_urls.append(url)

    return list(dict.fromkeys(map_urls))


def _filter_candidates_by_file_size(map_candidates: List[str]) -> List[str]:
    filtered: List[str] = []
    for candidate_url in map_candidates:
        try:
            head_response = requests.head(candidate_url, timeout=5, headers={"User-Agent": "Mozilla/5.0"})
            head_response.raise_for_status()
            content_length = head_response.headers.get("Content-Length")
            if content_length and int(content_length) / 1024 <= 50:
                continue
        except Exception:
            # Keep candidate if metadata is unavailable.
            pass
        filtered.append(candidate_url)
    return list(dict.fromkeys(filtered))


def _is_direct_map_url(url: str) -> bool:
    lowered = (url or "").lower()
    return lowered.endswith((".pdf", ".jpg", ".jpeg", ".png", ".webp")) and any(
        keyword in lowered for keyword in ["map", "directory", "floor"]
    )

