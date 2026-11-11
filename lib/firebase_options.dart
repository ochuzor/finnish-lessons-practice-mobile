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
  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _required('FIREBASE_WEB_API_KEY', _webApiKey),
    appId: '1:948871717050:web:98971e2a77ee6da1f1e283',
    messagingSenderId: '948871717050',
    projectId: 'language-learning-apps-a3f44',
    authDomain: 'language-learning-apps-a3f44.firebaseapp.com',
    storageBucket: 'language-learning-apps-a3f44.firebasestorage.app',
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _required('FIREBASE_ANDROID_API_KEY', _androidApiKey),
    appId: '1:948871717050:android:1ee3c33c4c1a4893f1e283',
    messagingSenderId: '948871717050',
    projectId: 'language-learning-apps-a3f44',
    storageBucket: 'language-learning-apps-a3f44.firebasestorage.app',
  );

  static String _required(String name, String value) {
    if (value.isEmpty) {
      throw StateError(
        '$name is missing. Start Flutter with '
        '--dart-define-from-file=firebase_config.local.json.',
      );
    }
    return value;
  }
}
