import os
import PIL.Image as Image
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# config for vlm
API_KEY = os.getenv("GOOGLE_API_KEY")
genai.configure(api_key=API_KEY)
model = genai.GenerativeModel("gemini-1.5-flash")

def get_spatial_narration(image_bytes, destination: str, map_context = None) -> str:
    img = Image.open(image_bytes)
    system_instructions = "prompt" #TODO: prompt
    context = f"\nMap context: {map_context}" if map_context else ""
    user_ask = f"Aditi wants to go to: {destination}"
    prompt = system_instructions + context + user_ask
    response = model.generate_content([prompt, img])
    return response.text



