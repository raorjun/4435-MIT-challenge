import io
from PIL import Image
from google import genai
from dotenv import load_dotenv

load_dotenv()
# The client automatically picks up the API key from os.environ["GOOGLE_API_KEY"]
client = genai.Client()


class VisionServiceError(Exception):
    """Raised when narration generation fails."""


def get_spatial_narration(image_bytes, destination, user_intent="", map_context=None):
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")

    # System instructions remain focused on Aditi's needs
    system_instructions = """
You are Steplight, a navigation assistant for Aditi, who has coloboma and is light-sensitive.
Analyze the image and provide ONE clear instruction.

Conversation and Intent Rules:
- The spoken user intent may be either specific ("take me to Nike") or broad
    ("I need sports clothes").
- Infer the likely destination type from broad intent and anchor guidance to
    visible evidence.
- If the request is ambiguous, ask one short clarifying question in sentence 2.
- Keep language direct and supportive.

Response format:
1. DIRECTION: Turn left/right, continue straight, or stop
2. DISTANCE: Estimate in feet
3. LANDMARK: Mention ONE visible feature (e.g., "blue door", "bright window")

Rules:
- Max 2 sentences.
- Use clock-face directions for landmarks (e.g., "elevator at 2 o'clock").
- ALERT her to high-glare areas (skylights, windows).

Landmark Logic:
The provided Map Context contains a list of known landmarks in this building.
Use these as primary anchor points for Aditi, but DO NOT be limited by them.
Treat the list as a starting point; if you see a landmark in the image that is
not in the list (e.g., a specific trash can, a different store sign, or a
temporary obstacle), prioritize what you see with your own eyes.
"""

    context = f"\n\nMap Context: {map_context}" if map_context else ""
    user_ask = (
        f"\n\nSpoken user intent: {user_intent or 'none provided.'}"
        f"\nAditi wants to go to: {destination}. What is the next step?"
    )

    full_text_prompt = f"{system_instructions}{context}{user_ask}"

    try:
        # Pass the image first, then the text for optimal processing
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[img, full_text_prompt]
        )
    except Exception as e:
        raise VisionServiceError(f"Narration generation failed: {str(e)}") from e

    response_text = (response.text or "").strip()
    if not response_text:
        raise VisionServiceError("Narration generation returned an empty response")

    return response_text
