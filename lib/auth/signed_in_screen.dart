import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/learner_api.dart';
import 'auth_service.dart';

class SignedInScreen extends StatefulWidget {
  const SignedInScreen({
    required this.auth,
    required this.learnerApi,
    required this.email,
    required this.enableBackendProfile,
    super.key,
  });

  final AuthService auth;
  final LearnerApi learnerApi;
  final String? email;
  final bool enableBackendProfile;

  @override
  State<SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<SignedInScreen> {
  bool _isSigningOut = false;
  bool _isProfileLoading = false;
  BackendUser? _backendUser;
  String? _signOutError;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    if (widget.enableBackendProfile) {
      _loadBackendProfile();
    }
  }

  Future<void> _loadBackendProfile() async {
    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });

    try {
      final user = await widget.learnerApi.getCurrentUser();
      if (mounted) setState(() => _backendUser = user);
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _profileError = error.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _profileError = 'Could not load your learning account.');
      }
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });

    try {
      await widget.auth.signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _signOutError =
              error.message ?? 'Could not sign out. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _signOutError = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
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
                      Text(
                        'You are signed in as',
                        style: theme.textTheme.bodyLarge,
                      ),
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
                      const SizedBox(height: 22),
                      _BackendProfileStatus(
                        enabled: widget.enableBackendProfile,
                        isLoading: _isProfileLoading,
                        user: _backendUser,
                        error: _profileError,
                        onRetry: _loadBackendProfile,
                      ),
                      if (_signOutError != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _signOutError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        onPressed: _isSigningOut ? null : _signOut,
                        icon: _isSigningOut
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

class _BackendProfileStatus extends StatelessWidget {
  const _BackendProfileStatus({
    required this.enabled,
    required this.isLoading,
    required this.user,
    required this.error,
    required this.onRetry,
  });

  final bool enabled;
  final bool isLoading;
  final BackendUser? user;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!enabled) {
      return Text(
        'Backend profile checks are available on your Android device.',
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    if (isLoading) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Flexible(child: Text('Connecting to your learning account…')),
        ],
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (user != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_done_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Learning account connected as ${user!.username}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
