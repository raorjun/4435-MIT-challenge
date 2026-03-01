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
