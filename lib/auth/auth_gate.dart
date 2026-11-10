import 'package:flutter/material.dart';

import '../api/learner_api.dart';
import 'auth_service.dart';
import 'signed_in_screen.dart';
import 'signed_out_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.auth,
    required this.learnerApi,
    required this.enableBackendProfile,
    super.key,
  });

  final AuthService auth;
  final LearnerApi learnerApi;
  final bool enableBackendProfile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        return user == null
            ? SignedOutScreen(auth: auth)
            : SignedInScreen(
                auth: auth,
                learnerApi: learnerApi,
                email: user.email,
                enableBackendProfile: enableBackendProfile,
              );
      },
    );
  }
}
