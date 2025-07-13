# GlobGram P2P - Deployment Guide

## Quick Deployment to GitHub Pages

### 1. Prepare Repository
```bash
git add .
git commit -m "Complete Stage D: Voice messages and final polish"
git push origin main
```

### 2. Build and Deploy
```bash
# Build web with correct base path
flutter build web --base-href /globgram-p2p/

# Create gh-pages branch (first time only)
git checkout -b gh-pages

# Copy build files
cp -r build/web/* .

# Add and commit
git add .
git commit -m "Deploy web build"

# Push to gh-pages
git push origin gh-pages

# Switch back to main
git checkout main
```

### 3. Enable GitHub Pages
1. Go to Repository Settings
2. Scroll to Pages section
3. Select Source: "Deploy from a branch"
4. Select Branch: "gh-pages"
5. Select Folder: "/ (root)"
6. Click Save

Your app will be available at: `https://tas-digitalmarket.github.io/globgram-p2p/`

## Firebase Configuration for Production

### 1. Add Production Domain
```javascript
// In Firebase Console > Authentication > Settings > Authorized domains
https://tas-digitalmarket.github.io
```

### 2. Update Firestore Rules for Production
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      // Only allow read/write for 24 hours
      allow read, write: if request.time < resource.time + duration.value(24, 'h');
      
      match /candidates/{candidateType} {
        allow read, write: if request.time < resource.time + duration.value(24, 'h');
        match /list/{candidateId} {
          allow read, write: if request.time < resource.time + duration.value(1, 'h');
        }
      }
    }
  }
}
```

### 3. Environment-Specific Configuration
Create different Firebase projects for development and production:

- Development: `globgram-p2p-dev`
- Production: `globgram-p2p-prod`

## Performance Optimization

### 1. Web Build Optimizations
```bash
# Build with optimization flags
flutter build web --release --dart2js-optimization O4 --source-maps
```

### 2. CDN Configuration
Consider using Firebase Hosting for better performance:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase Hosting
firebase init hosting

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## Monitoring and Analytics

### 1. Firebase Analytics
Add to `lib/main.dart`:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';

// Track room creation
FirebaseAnalytics.instance.logEvent(
  name: 'room_created',
  parameters: {'room_id': roomId},
);

// Track messages sent
FirebaseAnalytics.instance.logEvent(
  name: 'message_sent',
  parameters: {'type': messageType},
);
```

### 2. Error Reporting
Add Crashlytics for production error tracking:
```yaml
dependencies:
  firebase_crashlytics: ^3.4.8
```

## Security Considerations

### 1. WebRTC Security
- STUN servers are exposed - consider using TURN servers for production
- Implement room expiration (24 hours max)
- Add rate limiting for room creation

### 2. Data Privacy
- Voice messages are sent peer-to-peer (not stored)
- Only signaling data goes through Firebase
- Implement message encryption for sensitive use cases

## Load Testing

Test with multiple concurrent users:

```bash
# Use Artillery.js for load testing
npm install -g artillery

# Create test script (artillery-test.yml)
artillery run artillery-test.yml
```

## Custom Domain Setup

### 1. DNS Configuration
```
# Add CNAME record
globgram.yourdomain.com -> tas-digitalmarket.github.io
```

### 2. GitHub Pages Custom Domain
1. Add `CNAME` file to repository root:
```
globgram.yourdomain.com
```

2. Update Firebase authorized domains
3. Test HTTPS certificate

## Backup and Recovery

### 1. Firestore Backup
```bash
# Export Firestore data
gcloud firestore export gs://your-bucket/backup-folder
```

### 2. Repository Backup
- Enable repository backup to external storage
- Document critical configuration files
- Maintain deployment documentation

---

**🚀 Your GlobGram P2P app is now ready for production!**
