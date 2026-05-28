import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

enum AuthSignInMode {
  emailCode,
  password,
}

enum EmailOtpStep {
  enterEmail,
  enterCode,
}

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  StreamSubscription<HostAuthUser?>? _authSubscription;

  bool isBootstrapping = true;
  bool isSigningIn = false;
  AuthSignInMode signInMode = AuthSignInMode.emailCode;
  EmailOtpStep emailOtpStep = EmailOtpStep.enterEmail;
  bool isSendingCode = false;
  bool isVerifyingCode = false;
  String? submitError;
  String? pendingOtpEmail;
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

  void setSignInMode(AuthSignInMode mode) {
    signInMode = mode;
    submitError = null;
    notifyListeners();
  }

  void resetEmailOtp() {
    emailOtpStep = EmailOtpStep.enterEmail;
    pendingOtpEmail = null;
    submitError = null;
    notifyListeners();
  }

  Future<bool> sendEmailOtp({required String email}) async {
    isSendingCode = true;
    submitError = null;
    notifyListeners();

    try {
      final normalizedEmail = email.trim();
      await _authRepository.sendEmailOtp(email: normalizedEmail);
      pendingOtpEmail = normalizedEmail;
      emailOtpStep = EmailOtpStep.enterCode;
      isSendingCode = false;
      notifyListeners();
      return true;
    } catch (exception) {
      submitError = 'Unable to send a code right now.';
      isSendingCode = false;
      notifyListeners();
      return false;
    }
  }

  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    isVerifyingCode = true;
    submitError = null;
    notifyListeners();

    try {
      final host = await _authRepository.verifyEmailOtp(
        email: email.trim(),
        code: code.trim(),
      );
      currentHost = host;
      isVerifyingCode = false;
      notifyListeners();
      return host;
    } catch (exception) {
      submitError = _friendlyOtpMessageFor(exception);
      isVerifyingCode = false;
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

  String _friendlyOtpMessageFor(Object exception) {
    final message = exception.toString().toLowerCase();
    if (message.contains('expired') ||
        message.contains('invalid') ||
        message.contains('token')) {
      return 'That code is invalid or expired.';
    }

    return 'Unable to verify the code right now.';
  }
}
