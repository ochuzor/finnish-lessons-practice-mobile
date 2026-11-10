import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api/api_config.dart';
import 'api/learner_api.dart';
import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = FirebaseAuthService(FirebaseAuth.instance);
  final learnerApi = HttpLearnerApi(
    baseUrl: apiBaseUrl,
    idTokenProvider: auth.getIdToken,
  );

  runApp(
    FinnishLessonsApp(
      auth: auth,
      learnerApi: learnerApi,
      enableBackendProfile: !kIsWeb,
    ),
  );
}
