import '../models/auth_user.dart';
import 'auth_service.dart';

class DisabledCloudAuthService implements AuthService {
  static const message = 'Đồng bộ cloud chưa được cấu hình';

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw const AuthException(message);
  }

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw const AuthException(message);
  }

  @override
  Future<void> signOut() async {}
}
