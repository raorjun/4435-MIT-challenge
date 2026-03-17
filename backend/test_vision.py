from updated_vision import get_spatial_narration
import io

# Load test image
with open('bathroom_sign.jpeg', 'rb') as f:
    image_bytes = io.BytesIO(f.read())

# Test the VLM
narration = get_spatial_narration(
    image_bytes=image_bytes,
    destination="bathroom",
    map_context=None
)

print("\n" + "="*50)
print("GEMINI RESPONSE:")
print("="*50)
print(narration)
print("="*50 + "\n")