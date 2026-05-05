import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD64MhT8jlDavZ-t2k3KaU92EZn2z7NPD8',
    appId: '1:469636089136:web:50fdc76483f6395a9034f5',
    messagingSenderId: '469636089136',
    projectId: 'trust-app-a2a0e',
    authDomain: 'trust-app-a2a0e.firebaseapp.com',
    storageBucket: 'trust-app-a2a0e.firebasestorage.app',
    measurementId: 'G-C2MW19P965',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBXABXZwZFneInre2ZIH_hfjU2ke7NAqjI',
    appId: '1:469636089136:android:aafa4df1d5f689929034f5',
    messagingSenderId: '469636089136',
    projectId: 'trust-app-a2a0e',
    storageBucket: 'trust-app-a2a0e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBPgdRkxyyqKqFTdRZxPtzfx_oHr8Yu3ro',
    appId: '1:469636089136:ios:a23a8ef08fe837a99034f5',
    messagingSenderId: '469636089136',
    projectId: 'trust-app-a2a0e',
    storageBucket: 'trust-app-a2a0e.firebasestorage.app',
    iosBundleId: 'com.example.trustApp',
    iosClientId:
        '469636089136-8jk4873dkppormlk2qsskfkt6mtrf329.apps.googleusercontent.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD64MhT8jlDavZ-t2k3KaU92EZn2z7NPD8',
    appId: '1:469636089136:web:50fdc76483f6395a9034f5',
    messagingSenderId: '469636089136',
    projectId: 'trust-app-a2a0e',
    authDomain: 'trust-app-a2a0e.firebaseapp.com',
    storageBucket: 'trust-app-a2a0e.firebasestorage.app',
    measurementId: 'G-C2MW19P965',
  );
}
