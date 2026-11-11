# Finnish Lessons mobile

Flutter Android client for the Finnish Lessons backend.

## Local configuration

Firebase client API keys are supplied as compile-time environment values and
are not committed. Copy `firebase_config.example.json` to
`firebase_config.local.json`, then replace the placeholder values.

Run on the connected Android device with:

```powershell
flutter run -d <device-id> --dart-define-from-file=firebase_config.local.json
```

The local file is ignored by Git. Do not commit real Firebase keys, service
account credentials, or backend secrets.
