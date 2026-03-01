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
