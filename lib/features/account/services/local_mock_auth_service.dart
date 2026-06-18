import '../models/auth_user.dart';
import 'auth_service.dart';

class LocalMockAuthService implements AuthService {
  AuthUser? _currentUser;

  @override
  Future<AuthUser?> currentUser() async => _currentUser;

  @override
  Future<bool> isSignedIn() async => _currentUser != null;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _validate(email: email, password: password);
    _currentUser = AuthUser(
      id: 'mock-${email.trim().toLowerCase()}',
      email: email.trim(),
    );
    return _currentUser!;
  }

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  void _validate({required String email, required String password}) {
    if (!email.contains('@')) {
      throw const AuthException('Email không hợp lệ');
    }
    if (password.length < 6) {
      throw const AuthException('Mật khẩu cần ít nhất 6 ký tự');
    }
  }
}
