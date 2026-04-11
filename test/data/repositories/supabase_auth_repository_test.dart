import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.host});

  HostAuthUser? host;

  @override
  Stream<HostAuthUser?> authStateChanges() {
    return Stream<HostAuthUser?>.value(host);
  }

  @override
  HostAuthUser? get currentHost => host;

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    host = HostAuthUser(id: 'usr_01', email: email);
    return host;
  }

  @override
  Future<void> signOut() async {
    host = null;
  }
}

void main() {
  test('auth repository contract exposes current host and auth changes',
      () async {
    final repository = _FakeAuthRepository(
      host: const HostAuthUser(
        id: 'usr_01',
        email: 'host@example.com',
      ),
    );

    expect(repository.currentHost?.id, 'usr_01');
    await expectLater(
      repository.authStateChanges(),
      emits(
        const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.com',
        ),
      ),
    );
  });

  test('maps current user, auth changes, sign-in, and sign-out', () async {
    User? currentUser = const User(
      id: 'usr_01',
      appMetadata: {'provider': 'email'},
      userMetadata: null,
      aud: 'authenticated',
      email: 'brian.le1678@gmail.com',
      createdAt: '2026-04-11T00:00:00Z',
    );
    var signOutCalled = false;

    final repository = SupabaseAuthRepository(
      currentUserReader: () => currentUser,
      authStateChangesReader: () => Stream<AuthState>.value(
        AuthState(
          AuthChangeEvent.signedIn,
          null,
        ),
      ),
      signInWithPasswordAction: ({
        required String email,
        required String password,
      }) async {
        currentUser = User(
          id: 'usr_02',
          appMetadata: const {'provider': 'email'},
          userMetadata: null,
          aud: 'authenticated',
          email: email,
          createdAt: '2026-04-11T00:00:00Z',
        );
        return AuthResponse(user: currentUser);
      },
      signOutAction: () async {
        signOutCalled = true;
        currentUser = null;
      },
    );

    expect(
      repository.currentHost,
      const HostAuthUser(
        id: 'usr_01',
        email: 'brian.le1678@gmail.com',
      ),
    );

    await expectLater(
      repository.authStateChanges(),
      emits(
        const HostAuthUser(
          id: 'usr_01',
          email: 'brian.le1678@gmail.com',
        ),
      ),
    );

    expect(
      await repository.signInWithPassword(
        email: 'host@example.com',
        password: '12345678!',
      ),
      const HostAuthUser(
        id: 'usr_02',
        email: 'host@example.com',
      ),
    );

    await repository.signOut();
    expect(signOutCalled, isTrue);
    expect(repository.currentHost, isNull);
  });
}
