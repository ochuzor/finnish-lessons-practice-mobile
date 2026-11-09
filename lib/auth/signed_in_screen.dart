import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class SignedInScreen extends StatefulWidget {
  const SignedInScreen({
    required this.auth,
    required this.email,
    super.key,
  });

  final AuthService auth;
  final String? email;

  @override
  State<SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<SignedInScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.auth.signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message ?? 'Could not sign out. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.email?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Finnish Lessons')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.waving_hand_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tervetuloa!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('You are signed in as', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      Text(
                        email?.isNotEmpty == true ? email! : 'your account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Your learning dashboard will appear here next.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signOut,
                        icon: _isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
