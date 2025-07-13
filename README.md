# GlobGram P2P

A decentralized social media application built with Flutter.

## Features

- **Decentralized Architecture**: No central server required
- **Firestore Signaling**: Serverless WebRTC signaling via Firebase
- **Multi-language Support**: English and Persian (Farsi) localization
- **Cross-platform**: Runs on mobile, web, and desktop

## Current Stage: C - WebRTC Implementation

✅ **Completed:**
- Firebase integration with Firestore
- Signaling service for WebRTC room management
- **WebRTC P2P connections with real peer-to-peer communication**
- **Real-time chat messaging via data channels**
- Room creation and joining UI
- Connection status monitoring

### Stage C – WebRTC Test

To test the WebRTC P2P chat functionality:

1. **Open two browser tabs** (Chrome recommended):
   - Tab 1: `flutter run -d chrome`
   - Tab 2: Open another instance at `localhost:port`

2. **Create and join a room**:
   - Tab 1: Click "Create Room" → "Start P2P Chat"
   - Copy the Room ID displayed
   - Tab 2: Paste Room ID → "Join Room"

3. **Send messages**:
   - Wait for "Connected ✅" status in both tabs
   - Type messages and press Send
   - Messages appear instantly in both tabs via direct P2P connection

**Note**: Once connected, all communication is direct between browsers - no server involved!

🔄 **Next Stage:**
- Video/audio streaming capabilities

## Getting Started

### Prerequisites

- Flutter SDK 3.8.1+ (stable channel)
- Firebase project with Firestore enabled
- Compatible package versions:
  - firebase_core: ^3.8.0
  - cloud_firestore: ^5.4.4
  - flutter_webrtc: ^0.11.7
- Firebase CLI (recommended)

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

3. **Configure Firebase**:
   
   **Option A: Using FlutterFire CLI (Recommended)**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure your project
   flutterfire configure
   ```
   
   **Option B: Manual Configuration**
   - Create a Firebase project at https://console.firebase.google.com
   - Enable Firestore Database
   - Add your app to the Firebase project
   - Update `lib/firebase_options.dart` with your project settings:
   
   ```dart
   // Replace placeholder values with your actual Firebase config
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'your-actual-api-key',
     appId: 'your-actual-app-id',
     messagingSenderId: 'your-messaging-sender-id',
     projectId: 'your-actual-project-id',
     authDomain: 'your-project-id.firebaseapp.com',
     storageBucket: 'your-project-id.appspot.com',
   );
   ```

4. **Firestore Security Rules**:
   
   Set up basic security rules in Firebase Console:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Allow read/write access to rooms
       match /rooms/{roomId} {
         allow read, write: if true; // For testing only
         
         // Allow access to candidates subcollection
         match /candidates/{candidateType}/list/{candidateId} {
           allow read, write: if true; // For testing only
         }
       }
     }
   }
   ```
   
   ⚠️ **Note**: These rules are for testing only. Implement proper authentication and authorization for production.

### Running the App

#### Web (Chrome) - Recommended for testing
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
├── main.dart                           # App entry point
├── firebase_options.dart               # Firebase configuration
├── core/
│   └── signaling/
│       └── firestore_signaling_service.dart  # Firestore signaling implementation
└── pages/
    └── room_selection_page.dart        # Room creation/joining UI
assets/
├── translations/
    ├── en-US.json                      # English translations
    └── fa-IR.json                      # Persian translations
```

## Firestore Schema

The app uses the following Firestore structure:

```
rooms/{roomId}
├── offer: Map<String, dynamic>         # WebRTC offer
├── answer: Map<String, dynamic>        # WebRTC answer
├── createdAt: Timestamp
└── candidates/                         # ICE candidates collection
    ├── caller/
    │   └── list/{autoId}
    │       ├── candidate: String
    │       ├── sdpMid: String
    │       ├── sdpMLineIndex: int
    │       └── timestamp: Timestamp
    └── callee/
        └── list/{autoId}
            ├── candidate: String
            ├── sdpMid: String
            ├── sdpMLineIndex: int
            └── timestamp: Timestamp
```

## Usage

1. **Create a Room**:
   - Click "Create Room" button
   - Copy the generated Room ID
   - Share it with the person you want to connect with

2. **Join a Room**:
   - Paste the Room ID in the text field
   - Click "Join Room" button
   - The app will connect to the existing room

## Testing

Currently, the app implements signaling with mock data:
- Mock SDP offers and answers
- Firestore-based room management
- ICE candidate exchange structure

## Dependencies

- `firebase_core`: Firebase initialization
- `cloud_firestore`: Firestore database for signaling
- `flutter_webrtc`: WebRTC implementation for peer-to-peer connections
- `easy_localization`: Internationalization support

## Development Notes

This is **Stage C** of the GlobGram P2P project. The current implementation provides:
- ✅ Complete signaling service using Firestore
- ✅ Real WebRTC peer-to-peer connections
- ✅ Direct data channel communication (no server involved)
- ✅ Real-time chat messaging between peers
- ✅ Connection state monitoring and error handling
- ✅ Room creation and joining functionality
- ✅ Responsive UI with material design

**Key Features:**
- **True P2P Communication**: Once connected, no data passes through any server
- **End-to-End Encryption**: WebRTC provides built-in encryption
- **Real-Time Messaging**: Instant message delivery via data channels
- **Connection Resilience**: Automatic ICE candidate exchange and connection recovery

**Next stages will implement:**
- Video/audio streaming capabilities
- File sharing and transfer
- Group chat functionality
- Advanced P2P networking features

## Troubleshooting

### Common Issues

1. **Firebase not configured**: Make sure you've run `flutterfire configure` or manually updated `firebase_options.dart`

2. **Firestore permission denied**: Check your Firestore security rules

3. **Room not found**: Ensure the Room ID is copied correctly (case-sensitive)

4. **Connection issues**: Verify your internet connection and Firebase project status

### Debug Tips

- Check browser console for detailed error messages when running on web
- Use Firebase Console to monitor Firestore operations
- Enable Flutter debug logging for detailed information
