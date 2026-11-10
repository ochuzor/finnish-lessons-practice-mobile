import 'dart:async';

import 'package:finnishlessons/api/learner_api.dart';
import 'package:finnishlessons/app.dart';
import 'package:finnishlessons/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out screen submits credentials and sends reset email', (
    tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FinnishLessonsApp(auth: auth, learnerApi: FakeLearnerApi()),
    );
    await tester.pump();

    expect(find.text('Finnish Lessons'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'learner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret12',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(auth.lastEmail, 'learner@example.com');
    expect(auth.lastPassword, 'secret12');

    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(auth.passwordResetEmail, 'learner@example.com');
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('signed-in screen shows email and signs out', (tester) async {
    final auth = FakeAuthService(
      initialUser: const AppUser(email: 'me@example.com'),
    );
    addTearDown(auth.dispose);

    final learnerApi = FakeLearnerApi();
    await tester.pumpWidget(
      FinnishLessonsApp(auth: auth, learnerApi: learnerApi),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tervetuloa!'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(
      find.text('Learning account connected as test-learner'),
      findsOneWidget,
    );
    expect(learnerApi.callCount, 1);

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(auth.didSignOut, isTrue);
  });
}

class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? initialUser}) {
    _controller.add(initialUser);
  }

  final _controller = StreamController<AppUser?>();

  String? lastEmail;
  String? lastPassword;
  String? passwordResetEmail;
  bool didSignOut = false;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<String?> getIdToken() async => 'test-token';

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signOut() async {
    didSignOut = true;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

class FakeLearnerApi implements LearnerApi {
  int callCount = 0;

  @override
  Future<BackendUser> getCurrentUser() async {
    callCount++;
    return const BackendUser(id: 1, username: 'test-learner', isOwner: false);
  }
}
