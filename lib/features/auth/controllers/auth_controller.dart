import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  StreamSubscription<HostAuthUser?>? _authSubscription;

  bool isBootstrapping = true;
  bool isSigningIn = false;
  String? submitError;
  HostAuthUser? currentHost;

  bool get isSignedIn => currentHost != null;

  Future<void> bootstrap() async {
    currentHost = _authRepository.currentHost;
    isBootstrapping = false;
    submitError = null;
    _authSubscription ??= _authRepository.authStateChanges().listen((host) {
      currentHost = host;
      isBootstrapping = false;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<HostAuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    isSigningIn = true;
    submitError = null;
    notifyListeners();

    try {
      final host = await _authRepository.signInWithPassword(
        email: email,
        password: password,
      );
      currentHost = host;
      isSigningIn = false;
      notifyListeners();
      return host;
    } catch (exception) {
      submitError = _friendlyMessageFor(exception);
      isSigningIn = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    submitError = null;
    await _authRepository.signOut();
    currentHost = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _friendlyMessageFor(Object exception) {
    final message = exception.toString().toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }

    return 'Unable to sign in right now.';
  }
}
