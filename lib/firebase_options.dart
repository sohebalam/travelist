// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCwxOTyABS2O4VsKwF3_Lq2PmLsa6SfM2g',
    appId: '1:634216227694:web:74073069d6ac5a2c12577f',
    messagingSenderId: '634216227694',
    projectId: 'travelist-589cc',
    authDomain: 'travelist-589cc.firebaseapp.com',
    storageBucket: 'travelist-589cc.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBiseHRs6vsuUwvIdqNTgEilE9dW1cppd0',
    appId: '1:634216227694:android:cd5824c5739a638112577f',
    messagingSenderId: '634216227694',
    projectId: 'travelist-589cc',
    storageBucket: 'travelist-589cc.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBkp05mTEwgGdTu8JPVybj8Aft2gF2nyak',
    appId: '1:634216227694:ios:ca070c10c177f59a12577f',
    messagingSenderId: '634216227694',
    projectId: 'travelist-589cc',
    storageBucket: 'travelist-589cc.appspot.com',
    iosBundleId: 'com.example.travelist',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBkp05mTEwgGdTu8JPVybj8Aft2gF2nyak',
    appId: '1:634216227694:ios:ca070c10c177f59a12577f',
    messagingSenderId: '634216227694',
    projectId: 'travelist-589cc',
    storageBucket: 'travelist-589cc.appspot.com',
    iosBundleId: 'com.example.travelist',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCwxOTyABS2O4VsKwF3_Lq2PmLsa6SfM2g',
    appId: '1:634216227694:web:719435fa8ae917c212577f',
    messagingSenderId: '634216227694',
    projectId: 'travelist-589cc',
    authDomain: 'travelist-589cc.firebaseapp.com',
    storageBucket: 'travelist-589cc.appspot.com',
  );
}