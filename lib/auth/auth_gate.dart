import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'signed_in_screen.dart';
import 'signed_out_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({required this.auth, super.key});

  final AuthService auth;

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
            : SignedInScreen(auth: auth, email: user.email);
      },
    );
  }
}
