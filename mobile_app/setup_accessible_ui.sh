#!/bin/bash
# setup_accessible_ui.sh
# Run this from mobile_app/ directory

echo "🎨 Setting up Accessible UI..."

# Create directories
mkdir -p lib/widgets/accessible
mkdir -p lib/widgets/feedback
mkdir -p lib/screens

# Create widget files
touch lib/widgets/accessible/large_action_card.dart
touch lib/widgets/accessible/fullscreen_gesture_detector.dart
touch lib/widgets/accessible/gesture_zone.dart

# Create feedback files
touch lib/widgets/feedback/haptic_feedback_helper.dart
touch lib/widgets/feedback/audio_feedback_helper.dart

# Create screen files
touch lib/screens/accessible_home_screen.dart
touch lib/screens/accessible_navigation_screen.dart
touch lib/screens/destination_selection_screen.dart
touch lib/screens/gesture_tutorial_screen.dart

echo "✅ Files created!"
echo ""
echo "📂 Created structure:"
echo "  lib/widgets/accessible/"
echo "    ├── large_action_card.dart"
echo "    ├── fullscreen_gesture_detector.dart"
echo "    └── gesture_zone.dart"
echo ""
echo "  lib/widgets/feedback/"
echo "    ├── haptic_feedback_helper.dart"
echo "    └── audio_feedback_helper.dart"
echo ""
echo "  lib/screens/"
echo "    ├── accessible_home_screen.dart"
echo "    ├── accessible_navigation_screen.dart"
echo "    ├── destination_selection_screen.dart"
echo "    └── gesture_tutorial_screen.dart"
echo ""
echo "📋 Next steps:"
echo "1. Copy code from accessible_ui_framework_part1.md into each file"
echo "2. Add dependencies to pubspec.yaml:"
echo "   - flutter_tts: ^4.0.2"
echo "   - audioplayers: ^5.2.1"
echo "3. Run: flutter pub get"
echo "4. Run: flutter run"
