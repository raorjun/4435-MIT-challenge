"""
Vision Module - Gemini VLM Integration
Handles spatial narration and scene understanding for navigation
"""

import os
from PIL import Image
from google import genai
from dotenv import load_dotenv

load_dotenv()

# Configure Gemini API
API_KEY = os.getenv("GOOGLE_API_KEY")
client = genai.Client(api_key=API_KEY)


def get_spatial_narration(image_bytes, destination: str, map_context=None) -> str:
    """
    Analyze camera image and provide spatial navigation guidance
    
    Args:
        image_bytes: Image file in bytes (BytesIO object)
        destination: Where the user wants to go (e.g., "bathroom", "exit")
        map_context: Optional floor plan or map information
    
    Returns:
        str: Natural language navigation instruction
    """
    
    # Open image
    img = Image.open(image_bytes)
    
    # System instructions for navigation
    system_instructions = """You are a navigation assistant for a visually impaired person using a camera to find their way.

Your task: Analyze the camera image and provide ONE clear, immediate navigation instruction.

Response format:
1. DIRECTION: Turn left/right, continue straight, or stop
2. DISTANCE: Estimate in feet (e.g., "15 feet", "30 feet")
3. LANDMARK: Mention ONE visible sign, door, or feature to confirm location

Rules:
- Maximum 2 sentences
- Be specific and confident
- Use simple, direct language
- Prioritize safety (mention obstacles if visible)
- If destination is visible, say "You've arrived" or give final step

Examples:
"Turn left. The restroom sign is 15 feet ahead on your right."
"Continue straight for 20 feet. You'll pass a water fountain on your left."
"Stop. The exit door is directly in front of you, 5 feet ahead."
"""
    
    # Add map context if available
    context = ""
    if map_context:
        context = f"\n\nMap Information:\n{map_context}\n"
    
    # User's navigation request
    if destination.lower() == "describe the scene":
        user_ask = "Describe what you see in this image. Focus on identifying any visible signs, doors, hallways, or landmarks that could help with navigation."
    else:
        user_ask = f"\n\nThe user wants to navigate to: {destination}. Based on what you see in this camera image, what is the next step?"
    
    # Construct final prompt
    prompt = system_instructions + context + user_ask
    
    # Call Gemini VLM using new API
    try:
        response = client.models.generate_content(
            model='models/gemini-3-flash-preview',
            contents=[prompt, img]
        )
        return response.text.strip()
    except Exception as e:
        return f"Error getting navigation guidance: {str(e)}"