// Firebase client configuration is public application metadata, not a secret.
// Run `flutterfire configure` after Firebase CLI login to add the registered
// Android app configuration for com.ochuzor.finnishlessons.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => throw UnsupportedError(
        'Android Firebase configuration is pending. Run flutterfire configure.',
      ),
      _ => throw UnsupportedError(
        'Firebase is not configured for this platform.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC9OalUZEdxSkfioQFwyHX1ywfgX8OYg0Q',
    appId: '1:948871717050:web:98971e2a77ee6da1f1e283',
    messagingSenderId: '948871717050',
    projectId: 'language-learning-apps-a3f44',
    authDomain: 'language-learning-apps-a3f44.firebaseapp.com',
  );
}
