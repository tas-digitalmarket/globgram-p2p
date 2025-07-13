# GlobGram P2P

A decentralized social media application built with Flutter and WebRTC for true peer-to-peer communication.

![GlobGram P2P](screenshots/app_preview.png)

## 🌟 Features

- **🔒 Decentralized Architecture**: No central server required for communication
- **🔥 Firebase Signaling**: Serverless WebRTC signaling via Firestore
- **🎙️ Voice Messages**: Record and send voice clips with hold-to-record
- **💬 Real-time Chat**: Instant messaging with direct peer connections
- **🌍 Multi-language Support**: English and Persian (Farsi) localization
- **📱 Cross-platform**: Runs on mobile, web, and desktop
- **🎨 Modern UI**: Material Design 3 with dark mode support

## 🚀 Stage Progress

### ✅ Stage A - Flutter Skeleton + Firebase
- Firebase integration with Firestore
- Multi-language localization setup
- Basic UI structure

### ✅ Stage B - Firestore Signaling  
- WebRTC signaling service via Firestore
- Room creation and management
- ICE candidate exchange

### ✅ Stage C - WebRTC Implementation
- Peer-to-peer connections with data channels
- Real-time chat messaging
- Connection state monitoring

### ✅ Stage D - Voice & Final Polish
- **Voice recording with hold-to-record**
- **Voice message playback**
- **Enhanced UI with rounded cards and shadows**
- **Auto-scroll and dark mode friendly design**

## 🛠️ Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `globgram-p2p`
4. Enable Google Analytics (optional)
5. Click "Create project"

![Firebase Project Creation](screenshots/firebase_create_project.png)

### 2. Enable Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode"
4. Select location closest to your users
5. Click "Done"

![Firestore Setup](screenshots/firestore_setup.png)

### 3. Configure Web App

1. Click the web icon (`</>`) in project overview
2. Register app with name: `globgram-p2p-web`
3. Copy the configuration object
4. Replace the placeholder in `lib/firebase_options.dart`:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-api-key',
  authDomain: 'your-project.firebaseapp.com',
  projectId: 'your-project-id',
  storageBucket: 'your-project.appspot.com',
  messagingSenderId: '123456789',
  appId: 'your-app-id',
);
```

### 4. Configure Security Rules

Go to Firestore Database > Rules and update:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      allow read, write: if true;
      match /candidates/{candidateType} {
        allow read, write: if true;
        match /list/{candidateId} {
          allow read, write: if true;
        }
      }
    }
  }
}
```

![Firestore Rules](screenshots/firestore_rules.png)

## 📱 How to Use

### Creating a Room

1. Open the app
2. Click **"Create Room"**
3. Wait for room creation
4. Click **"Start P2P Chat"**
5. Share the displayed Room ID

![Create Room](screenshots/create_room.png)

### Joining a Room

1. Open the app in another browser/device
2. Enter the Room ID
3. Click **"Join Room"**
4. Wait for connection

![Join Room](screenshots/join_room.png)

### Voice Messages

1. **Hold** the microphone button to record
2. **Release** to send the voice message
3. **Tap** voice messages to play them

![Voice Messages](screenshots/voice_messages.png)

## 🔧 Development Setup

### Prerequisites

- Flutter SDK 3.8.1+ (stable channel)
- Dart SDK 3.8.1+
- Firebase project with Firestore enabled

### Dependencies

```yaml
dependencies:
  firebase_core: ^3.8.0
  cloud_firestore: ^5.4.4
  flutter_webrtc: ^0.11.7
  flutter_sound: ^9.2.13
  permission_handler: ^11.3.1
  easy_localization: ^3.0.7
```

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/tas-digitalmarket/globgram-p2p.git
   cd globgram-p2p
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Follow the Firebase setup steps above
   - Update `lib/firebase_options.dart`

4. **Run the application**
   ```bash
   # Web
   flutter run -d chrome
   
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   ```

## 🏗️ Build Commands

### Web Build
```bash
flutter build web --release
```

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🌐 Deployment

### GitHub Pages Deployment

1. **Build for web**
   ```bash
   flutter build web --base-href /globgram-p2p/
   ```

2. **Deploy to GitHub Pages**
   ```bash
   # Add build output to git
   git add build/web
   git commit -m "Deploy web build"
   git subtree push --prefix build/web origin gh-pages
   ```

3. **Configure Firebase**
   - Go to Firebase Console > Authentication > Settings
   - Add your GitHub Pages domain to authorized domains:
   ```
   https://yourusername.github.io
   ```

### Custom Domain Setup

1. **Add domain to Firebase**
   - Firebase Console > Hosting > Add custom domain
   - Follow DNS configuration steps

2. **Update CORS settings**
   - Ensure WebRTC works over HTTPS
   - Configure proper SSL certificates

## 🎮 Testing P2P Connection

### Local Testing
1. **Open two browser tabs**
   ```bash
   flutter run -d chrome
   ```
   - Tab 1: Create room → Start P2P Chat
   - Tab 2: Join room with Room ID

2. **Test features**
   - Send text messages
   - Record and send voice messages
   - Verify real-time communication

### Network Testing
1. **Different devices on same network**
   - Build and install on mobile devices
   - Use web version on computers
   - Test cross-platform communication

2. **Internet testing**
   - Deploy to GitHub Pages
   - Test with users in different locations
   - Verify STUN server connectivity

## 🔧 Technical Architecture

### WebRTC Flow
```
Caller                    Firestore                    Callee
  |                          |                          |
  |-- Create Room ---------->|                          |
  |<-- Room ID --------------|                          |
  |                          |<-- Join Room ------------|
  |<-- Answer ---------------|                          |
  |-- ICE Candidates ------->|-- ICE Candidates ------->|
  |<-- ICE Candidates -------|<-- ICE Candidates -------|
  |                          |                          |
  |<======= Direct P2P Connection ======>|
```

### Data Channel Messages
```json
{
  "id": "timestamp_random",
  "text": "Hello world",
  "timestamp": 1640995200000,
  "type": "MessageType.text",
  "voiceData": null
}
```

### Voice Message Format
```json
{
  "id": "timestamp_random", 
  "text": "[Voice Message]",
  "timestamp": 1640995200000,
  "type": "MessageType.voice",
  "voiceData": "base64EncodedAudioData"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for serverless infrastructure
- WebRTC for peer-to-peer communication
- Flutter Sound for audio recording capabilities

## 📞 Support

For support and questions:
- 📧 Email: support@globgram.dev
- 💬 GitHub Issues: [Create an issue](https://github.com/tas-digitalmarket/globgram-p2p/issues)
- 🌐 Website: [globgram.dev](https://globgram.dev)

---

**🌟 Star this repository if you found it helpful!** 

Built with ❤️ using Flutter & WebRTC
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
