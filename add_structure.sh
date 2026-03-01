#!/bin/bash
# add_structure.sh - Add project structure to existing repo

set -e  # Exit on error

echo "🔧 Adding structure to existing Indoor Navigation Assistant repo"
echo "=================================================================="

# Verify we're in a git repo
if [ ! -d .git ]; then
    echo "❌ Error: Not a git repository. Run 'git init' first."
    exit 1
fi

echo "✅ Git repository detected"

# Leave README.md completely untouched
echo "📋 Preserving your existing README.md"

# Create directory structure (won't overwrite existing dirs)
echo "📁 Creating directory structure..."

# Mobile app
mkdir -p mobile_app/{android,ios,test/{unit,widget,integration}}
mkdir -p mobile_app/lib/{config,models,services/{localization,navigation,vlm,audio,database},screens,widgets,utils}
mkdir -p mobile_app/assets/{images,fonts,sounds}

# Map processing
mkdir -p map_processing/{scripts,tools,data/{raw_maps,processed_maps,venue_database}}

# ML models
mkdir -p ml_models/{sign_detection/{train,data/{datasets,annotations},models,evaluate},store_logo_detection/{train,data,models},notebooks}

# Backend (optional)
mkdir -p backend/{api/{routes,models},database/migrations,config,tests}

# Data collection
mkdir -p data_collection/{wifi_fingerprinting/{collector_app,fingerprint_data},dataset_scripts}

# Docs
mkdir -p docs

# Scripts
mkdir -p scripts

# Research
mkdir -p research/{papers,benchmarks,experiments}

# Deployment
mkdir -p deployment/{mobile/{android,ios},backend}

echo "✅ Directory structure created"

# Create .gitkeep files for empty directories
echo "📝 Creating .gitkeep files..."
find . -type d -empty -not -path "./.git/*" -exec touch {}/.gitkeep \;

# Create/update .gitignore (append if exists)
echo "🚫 Updating .gitignore..."

cat >> .gitignore << 'EOF'

# ============================================
# Added by Indoor Nav Assistant setup script
# ============================================

# Flutter/Dart
mobile_app/.dart_tool/
mobile_app/.flutter-plugins
mobile_app/.flutter-plugins-dependencies
mobile_app/.packages
mobile_app/build/
mobile_app/ios/Pods/
mobile_app/ios/.symlinks/
mobile_app/.fvm/

# Android
mobile_app/android/.gradle/
mobile_app/android/captures/
mobile_app/android/local.properties
mobile_app/android/app/google-services.json

# iOS
mobile_app/ios/Flutter/
mobile_app/ios/.symlinks/
mobile_app/ios/Pods/

# Python
*.pyc
__pycache__/
*.py[cod]
*$py.class
venv/
env/
.venv/
ml_models/*/venv/
map_processing/venv/
backend/venv/

# ML Models
ml_models/*/data/datasets/*
!ml_models/*/data/datasets/.gitkeep
ml_models/*/runs/
*.pt
*.onnx
*.tflite
!ml_models/sign_detection/models/best.pt

# Data
map_processing/data/raw_maps/*
!map_processing/data/raw_maps/.gitkeep
map_processing/data/processed_maps/*
!map_processing/data/processed_maps/.gitkeep
data_collection/wifi_fingerprinting/fingerprint_data/*
!data_collection/wifi_fingerprinting/fingerprint_data/.gitkeep

# Environment & Secrets
.env
.env.local
*.key
mobile_app/lib/config/app_config.dart

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs/

# Database
*.db
*.sqlite
*.sqlite3

# Temporary files
tmp/
temp/
*.tmp
EOF

# Create CONTRIBUTING.md if doesn't exist
if [ ! -f CONTRIBUTING.md ]; then
cat > CONTRIBUTING.md << 'EOF'
# Contributing Guide

Thank you for your interest in contributing! 🎉

## How to Contribute

### Adding a New Venue

1. Collect floor plan images
2. Process using `map_processing/scripts/process_floor_plan.py`
3. Optional: Calibrate WiFi fingerprints
4. Submit PR with venue data

### Reporting Bugs

Open an issue with:
- Device & OS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### Code Style

- **Dart**: Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **Python**: Follow PEP 8
- Run linters before committing:
  ```bash
  cd mobile_app && flutter analyze
  ```

## Development Setup

See [docs/API_SETUP.md](docs/API_SETUP.md) for detailed instructions.

## Questions?

Open a discussion or create an issue!
EOF
fi

# Create LICENSE if doesn't exist
if [ ! -f LICENSE ]; then
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Indoor Navigation Assistant Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
fi

# Create mobile_app/pubspec.yaml
cat > mobile_app/pubspec.yaml << 'EOF'
name: indoor_nav_assistant
description: AI-powered indoor navigation for the visually impaired
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1
  
  # Sensors & Location
  camera: ^0.10.5
  sensors_plus: ^4.0.2
  geolocator: ^11.0.0
  wifi_scan: ^0.4.0
  pedometer: ^4.0.1
  
  # AI/ML
  google_generativeai: ^0.2.2
  tflite_flutter: ^0.10.4
  image: ^4.1.3
  
  # Audio
  flutter_tts: ^4.0.2
  
  # Storage
  sqflite: ^2.3.2
  path_provider: ^2.1.2
  shared_preferences: ^2.2.2
  
  # Network
  http: ^1.2.0
  
  # Utils
  permission_handler: ^11.2.0
  
  # UI
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/sounds/
EOF

# Create app config example
cat > mobile_app/lib/config/app_config.example.dart << 'EOF'
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
EOF

# Create main.dart stub
cat > mobile_app/lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';

void main() {
  // TODO: Initialize services
  runApp(const IndoorNavApp());
}

class IndoorNavApp extends StatelessWidget {
  const IndoorNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indoor Navigation Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // High contrast for accessibility
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.navigation,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Indoor Navigation Assistant',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'AI-powered guidance for the visually impaired',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to venue selection
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigation coming soon!')),
                );
              },
              icon: const Icon(Icons.map, size: 28),
              label: const Text(
                'Start Navigation',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to settings
              },
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
EOF

# Create Python requirements files
cat > map_processing/requirements.txt << 'EOF'
# Computer Vision
numpy>=1.24.0
opencv-python>=4.8.0
pytesseract>=0.3.10
pillow>=10.0.0

# Web Scraping
requests>=2.31.0
beautifulsoup4>=4.12.0
selenium>=4.15.0

# Data Processing
pandas>=2.0.0
scikit-learn>=1.3.0
scipy>=1.11.0

# Utilities
pyyaml>=6.0
python-dotenv>=1.0.0
tqdm>=4.66.0
EOF

cat > ml_models/sign_detection/requirements.txt << 'EOF'
# YOLOv8
ultralytics>=8.1.0

# Core ML/CV
torch>=2.1.0
torchvision>=0.16.0
opencv-python>=4.8.0
pillow>=10.0.0
numpy>=1.24.0

# Data augmentation
albumentations>=1.3.0

# Utilities
pyyaml>=6.0
tqdm>=4.66.0
matplotlib>=3.7.0
EOF

# Create setup script
cat > scripts/setup.sh << 'EOF'
#!/bin/bash

echo "🚀 Setting up Indoor Navigation Assistant..."
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter required but not installed. Visit: https://flutter.dev/docs/get-started/install"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python 3 required but not installed."; exit 1; }

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo "✅ Python found: $(python3 --version)"
echo ""

# Setup mobile app
echo "📱 Setting up Flutter mobile app..."
cd mobile_app

# Copy config example if app_config.dart doesn't exist
if [ ! -f lib/config/app_config.dart ]; then
    cp lib/config/app_config.example.dart lib/config/app_config.dart
    echo "✅ Created lib/config/app_config.dart"
    echo "⚠️  IMPORTANT: Edit this file and add your Gemini API key!"
    echo "   Get free key: https://makersuite.google.com/app/apikey"
else
    echo "⚠️  lib/config/app_config.dart already exists (not overwriting)"
fi

# Install Flutter dependencies
echo "Installing Flutter dependencies..."
flutter pub get
echo "✅ Flutter dependencies installed"

cd ..

# Setup Python environments
echo ""
echo "🐍 Setting up Python environments..."

# Map processing
if [ ! -d map_processing/venv ]; then
    echo "Creating virtual environment for map_processing..."
    cd map_processing
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    cd ..
    echo "✅ Map processing environment ready"
else
    echo "⚠️  map_processing/venv already exists (skipping)"
fi

# ML models
if [ ! -d ml_models/sign_detection/venv ]; then
    echo "Creating virtual environment for ML models..."
    cd ml_models/sign_detection
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    cd ../..
    echo "✅ ML models environment ready"
else
    echo "⚠️  ml_models/sign_detection/venv already exists (skipping)"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Get your FREE Gemini API key:"
echo "   → https://makersuite.google.com/app/apikey"
echo ""
echo "2. Edit mobile_app/lib/config/app_config.dart"
echo "   → Replace 'YOUR_GEMINI_API_KEY_HERE' with your key"
echo ""
echo "3. Run the app:"
echo "   → cd mobile_app"
echo "   → flutter run"
echo ""
echo "4. See docs/API_SETUP.md for detailed instructions"
echo ""
echo "Happy coding! 🎉"
EOF

chmod +x scripts/setup.sh

# Create documentation
cat > docs/API_SETUP.md << 'EOF'
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
EOF

cat > docs/ARCHITECTURE.md << 'EOF'
# System Architecture

## Overview

Indoor Navigation Assistant uses a **hybrid localization** approach combining:

1. **VIO** (Visual-Inertial Odometry) - ARKit/ARCore for drift-free tracking
2. **WiFi** Fingerprinting - Periodic position corrections
3. **Map Database** - Pre-loaded floor plans for pathfinding
4. **VLM Fallback** - Gemini 2.5 Flash-Lite when uncertain

## High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│          Mobile App (Flutter)                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌────────────────────────────────────────┐    │
│  │      Localization Layer                │    │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐ │    │
│  │  │   VIO    │ │   WiFi   │ │  Step  │ │    │
│  │  │ Tracker  │ │ Locator  │ │Counter │ │    │
│  │  └──────────┘ └──────────┘ └────────┘ │    │
│  │         │           │           │      │    │
│  │         └───────────┴───────────┘      │    │
│  │                  │                     │    │
│  │           Hybrid Fusion                │    │
│  └────────────────────────────────────────┘    │
│                    │                           │
│  ┌────────────────────────────────────────┐    │
│  │      Navigation Layer                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐ │    │
│  │  │   Map    │ │    A*    │ │ Gemini │ │    │
│  │  │ Database │ │Pathfinder│ │  VLM   │ │    │
│  │  └──────────┘ └──────────┘ └────────┘ │    │
│  └────────────────────────────────────────┘    │
│                    │                           │
│  ┌────────────────────────────────────────┐    │
│  │      Presentation Layer                │    │
│  │  ┌──────────┐ ┌──────────┐            │    │
│  │  │  Audio   │ │  Visual  │            │    │
│  │  │Feedback  │ │   UI     │            │    │
│  │  └──────────┘ └──────────┘            │    │
│  └────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌─────────────┐           ┌──────────────┐
  │ Local       │           │ Gemini API   │
  │ Map DB      │           │ (Cloud)      │
  │ (SQLite)    │           │ Flash-Lite   │
  └─────────────┘           └──────────────┘
```

## Data Flow

### Typical Navigation Session

1. **Initialization**
   - User opens app
   - GPS detects approximate location
   - App identifies venue (e.g., "SouthPark Mall")
   - Load floor plan from local database

2. **Position Initialization**
   - User selects entrance ("North Entrance")
   - VIO (ARKit/ARCore) session starts
   - Initial position set on map

3. **Destination Selection**
   - User speaks: "Take me to the bathroom"
   - App finds bathroom locations on floor plan
   - A* pathfinding calculates route

4. **Navigation Loop** (every 0.5 seconds)
   ```
   a. VIO updates position
   b. Every 10 seconds: WiFi correction
   c. Calculate distance to next waypoint
   d. Generate audio instruction
   e. Speak to user
   f. Check if arrived
   ```

5. **VLM Fallback** (when needed)
   - VIO confidence < 50%
   - User stuck (no progress 30 sec)
   - Approaching destination
   ```
   → Capture camera frame
   → Send to Gemini 2.5 Flash-Lite
   → Receive verbal guidance
   → Speak to user
   ```

## Key Design Decisions

### Why Hybrid Localization?

| Method | Accuracy | Drift | Cost | Works Offline |
|--------|----------|-------|------|---------------|
| GPS | 10-50m | None | Free | Yes |
| VIO only | 0.5-1m | Medium | Free | Yes |
| WiFi only | 3-5m | None | Free | Yes |
| **VIO + WiFi** | **0.3-0.8m** | **Minimal** | **Free** | **Yes** |
| VLM only | Variable | N/A | $$$$ | No |

**Conclusion**: VIO + WiFi gives best accuracy at zero cost, with VLM as intelligent fallback.

### Why Gemini 2.5 Flash-Lite?

- **4× more free requests** than Flash (1,000 vs 250/day)
- **70% cheaper** when scaled ($0.10 vs $0.30 per 1M tokens)
- **Faster** (lower latency)
- **Good enough** for navigation (91% vs 94% accuracy)

See [VLM Comparison Guide](../research/vlm_comparison.md) for full analysis.

## Technology Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Mobile** | Flutter | Cross-platform, fast development |
| **AR/VIO** | ARKit (iOS), ARCore (Android) | Industry standard, drift-free |
| **Database** | SQLite | Offline-first, lightweight |
| **VLM** | Gemini 2.5 Flash-Lite | Free tier, fast, cheap |
| **ML** | YOLOv8-nano | Mobile-optimized, accurate |
| **Audio** | Flutter TTS | Native, accessible |

## Performance Targets

- Position accuracy: < 1 meter
- Update rate: 2 Hz (twice per second)
- VLM latency: < 2 seconds
- Battery usage: < 15% per hour
- Works offline: Yes (map-based mode)

## Future Enhancements

- [ ] Store logo detection for better localization
- [ ] Multi-floor navigation
- [ ] Crowdsourced map updates
- [ ] AR visual overlays
- [ ] Offline voice synthesis
EOF

cat > docs/DEPLOYMENT.md << 'EOF'
# Deployment Guide

## Mobile App Deployment

### iOS (TestFlight)

Coming soon...

### Android (Google Play Beta)

Coming soon...

## Backend Deployment (Optional)

If you build the backend API:

### Docker
```bash
cd backend
docker build -t indoor-nav-backend .
docker run -p 8000:8000 indoor-nav-backend
```

### Heroku
```bash
heroku create indoor-nav-api
git push heroku main
```

More details coming soon...
EOF

# Create README for each major section
cat > mobile_app/README.md << 'EOF'
# Mobile App

Flutter-based mobile application for indoor navigation.

## Setup

```bash
flutter pub get
cp lib/config/app_config.example.dart lib/config/app_config.dart
# Edit app_config.dart with your API keys
flutter run
```

## Structure

- `lib/services/` - Core business logic
- `lib/screens/` - UI screens
- `lib/models/` - Data models
- `lib/widgets/` - Reusable widgets

## Testing

```bash
flutter test
```
EOF

cat > map_processing/README.md << 'EOF'
# Map Processing Tools

Tools for collecting and processing mall floor plans.

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Usage

### Process a floor plan
```bash
python scripts/process_floor_plan.py \
  --input data/raw_maps/mall_name/floor1.jpg \
  --output data/processed_maps/mall_name/
```

More tools coming soon...
EOF

cat > ml_models/README.md << 'EOF'
# Machine Learning Models

Training scripts for sign detection models.

## Setup

```bash
cd sign_detection
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Training

```bash
cd sign_detection
python train/train_yolo.py
```

See individual model directories for details.
EOF

# Git add and commit
echo ""
echo "📦 Staging changes..."
git add .

echo ""
echo "✅ Structure added to existing repository!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 What was added:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Complete directory structure"
echo "✅ Flutter mobile app skeleton"
echo "✅ Python tool setup"
echo "✅ Configuration files"
echo "✅ Documentation"
echo "✅ Setup scripts"
echo ""
echo "🔄 Your existing files were preserved:"
echo "   - README.md → backed up to README.old.md"
echo "   - .git directory → untouched"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Review changes:"
echo "   git status"
echo ""
echo "2. Run setup script:"
echo "   ./scripts/setup.sh"
echo ""
echo "3. Get Gemini API key:"
echo "   https://makersuite.google.com/app/apikey"
echo ""
echo "4. Commit when ready:"
echo "   git commit -m 'Add project structure'"
echo "   git push"
echo ""
echo "Happy coding! 🚀"
