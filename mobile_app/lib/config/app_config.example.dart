// Copy this to app_config.dart and add your API keys
// IMPORTANT: Never commit app_config.dart (it contains secrets)

class AppConfig {
  // ============================================
  // Gemini API Configuration
  // ============================================
  // Get your free API key: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  // ============================================
  // VLM Settings (Gemini 2.5 Flash-Lite)
  // ============================================
  static const String vlmModel = 'gemini-2.5-flash-lite';
  
  // Rate limiting (stay under free tier)
  static const int maxVLMCallsPerSession = 30;  // Max 30 calls per navigation
  static const Duration vlmCallInterval = Duration(seconds: 2);  // Min 2 sec between calls
  
  // Free tier limits: 1,000 requests/day, 15 requests/min
  static const int dailyVLMLimit = 1000;
  static const int perMinuteVLMLimit = 15;
  
  // ============================================
  // Localization Settings
  // ============================================
  static const bool useVIO = true;  // Visual-Inertial Odometry (ARKit/ARCore)
  static const bool useWiFi = true;  // WiFi fingerprinting
  static const bool useStepCounter = true;  // Pedometer fallback
  
  // ============================================
  // Navigation Settings
  // ============================================
  static const double positionUpdateInterval = 0.5;  // seconds
  static const double arrivalThreshold = 3.0;  // meters
  
  // ============================================
  // Audio Settings
  // ============================================
  static const double speechRate = 0.5;  // Slower for clarity
  static const double speechVolume = 1.0;
  static const String speechLanguage = 'en-US';
  
  // ============================================
  // Feature Flags
  // ============================================
  static const bool enableVLM = true;
  static const bool enableStoreLogoDetection = false;  // Coming soon
  static const bool enableAnalytics = false;
  
  // ============================================
  // Debug Settings
  // ============================================
  static const bool debugMode = true;
  static const bool verboseLogging = true;
  static const bool showDebugOverlay = true;
}
