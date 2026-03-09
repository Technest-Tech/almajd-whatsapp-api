import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAYiF_C_NgINH8DvpYC0y3eR_cFN3A2HDc',
    appId: '1:449886354083:android:132e69019a227039421d16',
    messagingSenderId: '449886354083',
    projectId: 'almajd-whatsapp',
    storageBucket: 'almajd-whatsapp.firebasestorage.app',
  );

  // iOS config — update if you have an iOS app registered in Firebase
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAYiF_C_NgINH8DvpYC0y3eR_cFN3A2HDc',
    appId: '1:449886354083:ios:000000000000000000000000', // placeholder — add real iOS app ID
    messagingSenderId: '449886354083',
    projectId: 'almajd-whatsapp',
    storageBucket: 'almajd-whatsapp.firebasestorage.app',
    iosBundleId: 'com.almajd.academy.almajdMobile',
  );
}
