import '../models/auth_user.dart';

abstract class AuthService {
  Future<AuthUser?> currentUser();

  Future<bool> isSignedIn();

  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
