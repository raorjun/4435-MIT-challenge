import io
from PIL import Image
from google import genai
from dotenv import load_dotenv

load_dotenv()
# The client automatically picks up the API key from os.environ["GOOGLE_API_KEY"]
client = genai.Client()


def get_spatial_narration(image_bytes, destination, map_context=None):
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")

    # System instructions remain focused on Aditi's needs
    system_instructions = """
You are Steplight, a navigation assistant for Aditi, who has coloboma and is light-sensitive.
Analyze the image and provide ONE clear instruction.

Response format:
1. DIRECTION: Turn left/right, continue straight, or stop
2. DISTANCE: Estimate in feet
3. LANDMARK: Mention ONE visible feature (e.g., "blue door", "bright window")

Rules:
- Max 2 sentences.
- Use clock-face directions for landmarks (e.g., "elevator at 2 o'clock").
- ALERT her to high-glare areas (skylights, windows).
"""

    context = f"\n\nMap Context: {map_context}" if map_context else ""
    user_ask = f"\n\nAditi wants to go to: {destination}. What is the next step?"

    full_text_prompt = f"{system_instructions}{context}{user_ask}"

    try:
        # Pass the image first, then the text for optimal processing
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview',
            contents=[img, full_text_prompt]
        )
        return response.text.strip()
    except Exception as e:
        return f"Navigation error: {str(e)}"
