import 'auth_user.dart';

enum AuthStatus { signedOut, signedIn, localOnly, cloudNotConfigured }

class AuthState {
  const AuthState({required this.status, this.user, this.message});

  final AuthStatus status;
  final AuthUser? user;
  final String? message;

  bool get isSignedIn => user != null && status == AuthStatus.signedIn;

  static const localOnly = AuthState(
    status: AuthStatus.localOnly,
    message: 'Cloud chưa được cấu hình',
  );
}
