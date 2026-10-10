import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBJf3s9fA1jW8Lk9NlczHu1DlcnwN5Ct1E',
    appId: '1:820960090976:web:698d3af43941f0ad2e1c05',
    messagingSenderId: '820960090976',
    projectId: 'reya-filling-station-chatrai',
    authDomain: 'reya-filling-station-chatrai.firebaseapp.com',
    storageBucket: 'reya-filling-station-chatrai.firebasestorage.app',
    measurementId: 'G-88CEBC7WR2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJf3s9fA1jW8Lk9NlczHu1DlcnwN5Ct1E',
    appId: '1:820960090976:android:698d3af43941f0ad2e1c05',
    messagingSenderId: '820960090976',
    projectId: 'reya-filling-station-chatrai',
    storageBucket: 'reya-filling-station-chatrai.firebasestorage.app',
  );
}
