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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      default:
        return windows;
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

  // Windows & Desktop config
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIuZIVFYj5_9WPCDLeAjtrRxUs8LdnKfM',
    appId: '1:214014462007:web:de6dabd73f9614682c97b2',
    messagingSenderId: '214014462007',
    projectId: 'imago-bbd56',
    storageBucket: 'imago-bbd56.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBIuZIVFYj5_9WPCDLeAjtrRxUs8LdnKfM',
    appId: '1:214014462007:ios:de6dabd73f9614682c97b2',
    messagingSenderId: '214014462007',
    projectId: 'imago-bbd56',
    storageBucket: 'imago-bbd56.firebasestorage.app',
    iosBundleId: 'org.lifechangerstouch.imago',
  );
}
