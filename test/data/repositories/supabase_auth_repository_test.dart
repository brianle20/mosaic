import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.host});

  HostAuthUser? host;
  String? sentOtpEmail;
  String? verifiedOtpEmail;
  String? verifiedOtpCode;

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
  Future<void> sendEmailOtp({required String email}) async {
    sentOtpEmail = email;
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    verifiedOtpEmail = email;
    verifiedOtpCode = code;
    host = HostAuthUser(id: 'usr_otp', email: email);
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

  test('auth repository contract exposes email OTP actions', () async {
    final repository = _FakeAuthRepository();

    await repository.sendEmailOtp(email: 'helper@example.com');
    expect(repository.sentOtpEmail, 'helper@example.com');

    expect(
      await repository.verifyEmailOtp(
        email: 'helper@example.com',
        code: '123456',
      ),
      const HostAuthUser(
        id: 'usr_otp',
        email: 'helper@example.com',
      ),
    );
    expect(repository.verifiedOtpEmail, 'helper@example.com');
    expect(repository.verifiedOtpCode, '123456');
  });

  test('maps current user, auth changes, sign-in, and sign-out', () async {
    User? currentUser = const User(
      id: 'usr_01',
      appMetadata: {'provider': 'email'},
      userMetadata: null,
      aud: 'authenticated',
      email: 'host@example.test',
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
      sendEmailOtpAction: ({
        required String email,
        required bool shouldCreateUser,
      }) async {
        expect(shouldCreateUser, isFalse);
      },
      verifyEmailOtpAction: ({
        required String email,
        required String token,
        required OtpType type,
      }) async {
        currentUser = User(
          id: 'usr_otp',
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
        email: 'host@example.test',
      ),
    );

    await expectLater(
      repository.authStateChanges(),
      emits(
        const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
      ),
    );

    expect(
      await repository.signInWithPassword(
        email: 'host@example.com',
        password: 'correct-horse-test!',
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

  test('sends and verifies email OTP through injected Supabase actions',
      () async {
    User? currentUser;
    String? sentOtpEmail;
    bool? shouldCreateOtpUser;
    String? verifiedOtpEmail;
    String? verifiedOtpCode;
    OtpType? verifiedOtpType;

    final repository = SupabaseAuthRepository(
      currentUserReader: () => currentUser,
      authStateChangesReader: () => const Stream<AuthState>.empty(),
      signInWithPasswordAction: ({
        required String email,
        required String password,
      }) async {
        throw UnimplementedError();
      },
      sendEmailOtpAction: ({
        required String email,
        required bool shouldCreateUser,
      }) async {
        sentOtpEmail = email;
        shouldCreateOtpUser = shouldCreateUser;
      },
      verifyEmailOtpAction: ({
        required String email,
        required String token,
        required OtpType type,
      }) async {
        verifiedOtpEmail = email;
        verifiedOtpCode = token;
        verifiedOtpType = type;
        currentUser = User(
          id: 'usr_email_otp',
          appMetadata: const {'provider': 'email'},
          userMetadata: null,
          aud: 'authenticated',
          email: email,
          createdAt: '2026-05-27T00:00:00Z',
        );
        return AuthResponse(user: currentUser);
      },
      signOutAction: () async {},
    );

    await repository.sendEmailOtp(email: 'helper@example.com');
    expect(sentOtpEmail, 'helper@example.com');
    expect(shouldCreateOtpUser, isFalse);

    expect(
      await repository.verifyEmailOtp(
        email: 'helper@example.com',
        code: '123456',
      ),
      const HostAuthUser(
        id: 'usr_email_otp',
        email: 'helper@example.com',
      ),
    );
    expect(verifiedOtpEmail, 'helper@example.com');
    expect(verifiedOtpCode, '123456');
    expect(verifiedOtpType, OtpType.email);
  });
}
