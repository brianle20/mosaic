import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.current,
    MosaicAccessState? access,
  }) : access = access ?? _approvedAccess();

  HostAuthUser? current;
  MosaicAccessState access;
  Future<MosaicAccessState>? nextAccess;
  var loadAccessCount = 0;
  final StreamController<HostAuthUser?> controller =
      StreamController<HostAuthUser?>.broadcast();
  Object? signInError;
  Object? sendOtpError;
  Object? verifyOtpError;
  String? sentOtpEmail;
  String? verifiedOtpEmail;
  String? verifiedOtpCode;

  @override
  Stream<HostAuthUser?> authStateChanges() => controller.stream;

  @override
  HostAuthUser? get currentHost => current;

  @override
  Future<MosaicAccessState> loadCurrentAccess() async {
    loadAccessCount += 1;
    final pending = nextAccess;
    nextAccess = null;
    return pending ?? access;
  }

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (signInError != null) {
      throw signInError!;
    }

    current = HostAuthUser(id: 'usr_02', email: email);
    controller.add(current);
    return current;
  }

  @override
  Future<void> sendEmailOtp({required String email}) async {
    if (sendOtpError != null) {
      throw sendOtpError!;
    }
    sentOtpEmail = email;
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    if (verifyOtpError != null) {
      throw verifyOtpError!;
    }
    verifiedOtpEmail = email;
    verifiedOtpCode = code;
    current = HostAuthUser(id: 'usr_otp', email: email);
    controller.add(current);
    return current;
  }

  @override
  Future<void> signOut() async {
    current = null;
    controller.add(null);
  }
}

MosaicAccessState _approvedAccess() {
  return const MosaicAccessState(
    userId: 'usr_01',
    isActive: true,
    events: [
      MosaicAccessEvent(
        eventId: 'evt_01',
        title: 'Friday Night Mahjong',
        role: MosaicAccessRole.owner,
      ),
    ],
  );
}

MosaicAccessState _disabledAccess() {
  return const MosaicAccessState(
    userId: 'usr_01',
    isActive: false,
    events: [],
  );
}

void main() {
  group('AuthController', () {
    test('defaults to email code mode and enter email step', () {
      final controller = AuthController(authRepository: _FakeAuthRepository());

      expect(controller.signInMode, AuthSignInMode.emailCode);
      expect(controller.emailOtpStep, EmailOtpStep.enterEmail);
      expect(controller.isSendingCode, isFalse);
      expect(controller.isVerifyingCode, isFalse);
    });

    test('starts bootstrapping and resolves signed out with no current host',
        () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      expect(controller.isBootstrapping, isTrue);

      await controller.bootstrap();

      expect(controller.isBootstrapping, isFalse);
      expect(controller.currentHost, isNull);
      expect(controller.isSignedIn, isFalse);
    });

    test('resolves signed in when a current host exists', () async {
      final repository = _FakeAuthRepository(
        current: const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
      );
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();

      expect(
        controller.currentHost,
        const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
      );
      expect(controller.isSignedIn, isTrue);
    });

    test('signed in host without approved access is not app signed in',
        () async {
      final repository = _FakeAuthRepository(
        current: const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
        access: const MosaicAccessState(
          userId: 'usr_01',
          isActive: true,
          events: [],
        ),
      );
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();

      expect(controller.hasAuthenticatedHost, isTrue);
      expect(controller.isSignedIn, isFalse);
      expect(
        controller.submitError,
        contains('not approved for any events'),
      );
    });

    test('recovery refresh replaces cached access with remote access',
        () async {
      final repository = _FakeAuthRepository(
        current: const HostAuthUser(id: 'usr_01', email: 'host@example.test'),
        access: _approvedAccess(),
      );
      final controller = AuthController(authRepository: repository);
      await controller.bootstrap();

      repository.access = _disabledAccess();
      await controller.refreshAccessAfterRecovery();

      expect(controller.currentAccess, _disabledAccess());
      expect(controller.isSignedIn, isFalse);
      expect(
        controller.submitError,
        'Your Mosaic access is disabled. Ask an event owner for help.',
      );
      controller.dispose();
    });

    test('overlapping recovery refreshes make one repository call', () async {
      final repository = _FakeAuthRepository(
        current: const HostAuthUser(id: 'usr_01', email: 'host@example.test'),
      );
      final controller = AuthController(authRepository: repository);
      await controller.bootstrap();
      final completer = Completer<MosaicAccessState>();
      repository.nextAccess = completer.future;

      final first = controller.refreshAccessAfterRecovery();
      final second = controller.refreshAccessAfterRecovery();
      completer.complete(_approvedAccess());
      await Future.wait([first, second]);

      expect(repository.loadAccessCount, 2);
      controller.dispose();
    });

    test('reports a friendly error when sign in fails', () async {
      final repository = _FakeAuthRepository()
        ..signInError = Exception('Invalid login credentials');
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      final result = await controller.signIn(
        email: 'host@example.test',
        password: 'wrong-password',
      );

      expect(result, isNull);
      expect(controller.submitError, 'Invalid email or password.');
      expect(controller.isSigningIn, isFalse);
      expect(controller.isSignedIn, isFalse);
    });

    test('sends email OTP and stores pending email', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      final sent = await controller.sendEmailOtp(email: 'helper@example.com');

      expect(sent, isTrue);
      expect(repository.sentOtpEmail, 'helper@example.com');
      expect(controller.pendingOtpEmail, 'helper@example.com');
      expect(controller.emailOtpStep, EmailOtpStep.enterCode);
      expect(controller.submitError, isNull);
      expect(controller.isSendingCode, isFalse);
    });

    test('surfaces friendly email OTP send failures', () async {
      final repository = _FakeAuthRepository()
        ..sendOtpError = Exception('rate limit exceeded');
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      final sent = await controller.sendEmailOtp(email: 'helper@example.com');

      expect(sent, isFalse);
      expect(controller.submitError, 'Unable to send a code right now.');
      expect(controller.emailOtpStep, EmailOtpStep.enterEmail);
      expect(controller.isSendingCode, isFalse);
    });

    test('verifies email OTP and signs in', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      final host = await controller.verifyEmailOtp(
        email: 'helper@example.com',
        code: '123456',
      );

      expect(
        host,
        const HostAuthUser(id: 'usr_otp', email: 'helper@example.com'),
      );
      expect(repository.verifiedOtpEmail, 'helper@example.com');
      expect(repository.verifiedOtpCode, '123456');
      expect(controller.currentHost, host);
      expect(controller.isSignedIn, isTrue);
      expect(controller.isVerifyingCode, isFalse);
    });

    test('surfaces friendly invalid email OTP failures', () async {
      final repository = _FakeAuthRepository()
        ..verifyOtpError = Exception('Token has expired or is invalid');
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      final host = await controller.verifyEmailOtp(
        email: 'helper@example.com',
        code: '000000',
      );

      expect(host, isNull);
      expect(controller.submitError, 'That code is invalid or expired.');
      expect(controller.isSignedIn, isFalse);
      expect(controller.isVerifyingCode, isFalse);
    });

    test('signs out and returns to signed out state', () async {
      final repository = _FakeAuthRepository(
        current: const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
      );
      final controller = AuthController(authRepository: repository);

      await controller.bootstrap();
      await controller.signOut();

      expect(controller.currentHost, isNull);
      expect(controller.currentAccess, isNull);
      expect(controller.isSignedIn, isFalse);
    });
  });
}
