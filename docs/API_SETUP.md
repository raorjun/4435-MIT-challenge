# API Setup Guide

## Getting a Gemini API Key (FREE!)

### Step 1: Visit Google AI Studio
Go to: [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)

### Step 2: Get API Key
1. Click "Get API Key" or "Create API Key"
2. Select "Create API key in new project" (recommended)
3. Copy the key (looks like: `AIzaSy...`)

### Step 3: Configure the App

1. Open `mobile_app/lib/config/app_config.dart`
2. Find this line:
   ```dart
   static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
   ```
3. Replace with your key:
   ```dart
   static const String geminiApiKey = 'AIzaSy...YOUR_ACTUAL_KEY';
   ```
4. Save the file

### Step 4: Test
```bash
cd mobile_app
flutter run
```

## Free Tier Limits

**Gemini 2.5 Flash-Lite:**
- ✅ 1,000 requests per day FREE
- ✅ 15 requests per minute
- ✅ No credit card required
- ✅ Perfect for 30+ test users

## Troubleshooting

### "API key invalid"
- Check you copied the entire key
- Remove any extra spaces or quotes
- Generate a new key if needed

### "Rate limit exceeded"
- You hit 1,000 requests/day limit
- Wait until next day (resets at midnight PT)
- Or enable billing for higher limits

### "PERMISSION_DENIED"
- Ensure API key is enabled for Gemini API
- Check in Google Cloud Console

## Cost Optimization

Stay under free tier:
- Limit VLM calls to 30 per session
- Use 2-second minimum between calls
- Prefer VIO/WiFi localization (free)
- Only use VLM when lost or stuck

See app_config.dart for optimization settings.
