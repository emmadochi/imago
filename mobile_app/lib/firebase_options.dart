// File generated manually from google-services.json
// Project: imago-bbd56 | Package: org.lifechangerstouch.imago
// To regenerate, run: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Reconfigure your web app using the Firebase console.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS yet. '
          'Download GoogleService-Info.plist from Firebase console and run: flutterfire configure',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android config — sourced from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIuZIVFYj5_9WPCDLeAjtrRxUs8LdnKfM',
    appId: '1:214014462007:android:de6dabd73f9614682c97b2',
    messagingSenderId: '214014462007',
    projectId: 'imago-bbd56',
    storageBucket: 'imago-bbd56.firebasestorage.app',
  );
}
