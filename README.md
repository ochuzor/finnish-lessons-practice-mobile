# Finnish Lessons mobile

Flutter Android client for the Finnish Lessons backend.

## Local configuration

Firebase client API keys are supplied as compile-time environment values and
are not committed. Keep separate local configuration files so Android builds
never receive the Web key and Web builds never receive the Android key.

For Android, copy `firebase_config.android.example.json` to
`firebase_config.android.local.json`, add the Android key, then run:

```powershell
flutter run -d <device-id> --dart-define-from-file=firebase_config.android.local.json
```

For Chrome, copy `firebase_config.web.example.json` to
`firebase_config.web.local.json`, add the Web key, then run:

```powershell
flutter run -d chrome --dart-define-from-file=firebase_config.web.local.json
```

All `*.local.json` files named above are ignored by Git. Do not commit real
Firebase keys, service account credentials, or backend secrets.
