import 'package:flutter/foundation.dart';

import '../models/auth_state.dart';
import '../services/auth_service.dart';
import '../services/disabled_cloud_auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService);

  final AuthService _authService;

  AuthState _state = AuthState.localOnly;
  bool _isBusy = false;

  AuthState get state => _state;
  bool get isBusy => _isBusy;

  Future<void> load() async {
    final user = await _authService.currentUser();
    _state = user == null
        ? AuthState.localOnly
        : AuthState(status: AuthStatus.signedIn, user: user);
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _run(() async {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _state = AuthState(status: AuthStatus.signedIn, user: user);
    });
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
      );
      _state = AuthState(status: AuthStatus.signedIn, user: user);
    });
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _state = AuthState.localOnly;
    notifyListeners();
  }

  void markCloudNotConfigured() {
    _state = const AuthState(
      status: AuthStatus.cloudNotConfigured,
      message: DisabledCloudAuthService.message,
    );
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
