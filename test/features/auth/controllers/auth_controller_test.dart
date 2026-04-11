import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.current});

  HostAuthUser? current;
  final StreamController<HostAuthUser?> controller =
      StreamController<HostAuthUser?>.broadcast();
  Object? signInError;

  @override
  Stream<HostAuthUser?> authStateChanges() => controller.stream;

  @override
  HostAuthUser? get currentHost => current;

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
  Future<void> signOut() async {
    current = null;
    controller.add(null);
  }
}

void main() {
  group('AuthController', () {
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
      expect(controller.isSignedIn, isFalse);
    });
  });
}
