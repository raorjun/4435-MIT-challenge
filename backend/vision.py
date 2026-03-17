import io
from google import genai
from google.genai import types
from PIL import Image
from dotenv import load_dotenv

load_dotenv()
# since api key is named GOOGLE_API_KEY, genai will autofill it from the environment variable
client = genai.Client()


def get_spatial_narration(image_bytes, destination, map_context = None):
    img = Image.open(io.BytesIO(image_bytes))
    system_instruction = "" #TODO

    user_ask = f"Aditi wants to go to: {destination}."
    if map_context:
        user_ask += f"\nAdditional Map/GPS Context: {map_context}"

    response = client.models.generate_content(
        model="gemini-1.5-flash",
        contents=[img, user_ask],
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.4,  # Lower temperature for more factual, less "creative" directions
        )
    )

    return response.text
