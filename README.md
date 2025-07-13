# GlobGram P2P

A decentralized social media application built with Flutter.

## Features

- **Decentralized Architecture**: No central server required
- **Firebase Integration**: Ready for cloud services
- **Multi-language Support**: English and Persian (Farsi) localization
- **Cross-platform**: Runs on mobile, web, and desktop

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Firebase CLI (optional, for Firebase configuration)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd globgram_p2p
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase (optional):
   - Update `lib/firebase_options.dart` with your Firebase project settings
   - Or use FlutterFire CLI: `flutterfire configure`

### Running the App

#### Web (Chrome)
```bash
flutter run -d chrome
```

#### Mobile (Android/iOS)
```bash
flutter run
```

#### Desktop
```bash
flutter run -d windows   # For Windows
flutter run -d macos     # For macOS
flutter run -d linux     # For Linux
```

## Project Structure

```
lib/
├── main.dart              # App entry point with Firebase & localization setup
├── firebase_options.dart  # Firebase configuration
assets/
├── translations/
    ├── en-US.json         # English translations
    └── fa-IR.json         # Persian translations
```

## Configuration

### Firebase Setup
Replace placeholder values in `lib/firebase_options.dart` with your actual Firebase project configuration.

### Localization
Add new languages by:
1. Creating translation files in `assets/translations/`
2. Adding locale to `supportedLocales` in `main.dart`

## Dependencies

- `firebase_core`: Firebase initialization
- `cloud_firestore`: Firestore database
- `easy_localization`: Internationalization support

## Development Notes

This is Stage A of the GlobGram P2P project. The current implementation provides:
- Complete Flutter skeleton
- Firebase integration setup
- Localization framework
- Basic UI structure

Future stages will implement P2P networking, decentralized messaging, and social media features.
