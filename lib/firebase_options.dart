import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
    appId: '1:1050660893959:web:184cdfde961e1a7344c1a2',
    messagingSenderId: '1050660893959',
    projectId: 'just-paste-79281',
    authDomain: 'just-paste-79281.firebaseapp.com',
    storageBucket: 'just-paste-79281.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
    appId: '1:1050660893959:android:184cdfde961e1a7344c1a2',
    messagingSenderId: '1050660893959',
    projectId: 'just-paste-79281',
    storageBucket: 'just-paste-79281.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
    appId: '1:1050660893959:ios:184cdfde961e1a7344c1a2',
    messagingSenderId: '1050660893959',
    projectId: 'just-paste-79281',
    storageBucket: 'just-paste-79281.firebasestorage.app',
    iosBundleId: 'com.example.justpaste',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
    appId: '1:1050660893959:ios:184cdfde961e1a7344c1a2',
    messagingSenderId: '1050660893959',
    projectId: 'just-paste-79281',
    storageBucket: 'just-paste-79281.firebasestorage.app',
    iosBundleId: 'com.example.justpaste',
  );
}
