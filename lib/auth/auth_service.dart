import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  const AppUser({required this.email});

  final String? email;
}

abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  Future<String?> getIdToken();
  Future<void> signIn({required String email, required String password});
  Future<void> createAccount({required String email, required String password});
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : AppUser(email: user.email),
  );

  @override
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
