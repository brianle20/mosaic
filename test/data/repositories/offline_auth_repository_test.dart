import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/repositories/offline_auth_repository.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineAuthRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('successful loadCurrentAccess caches access state', () async {
      final cache = await LocalCache.create();
      final inner = _FakeAuthRepository(access: _access('usr_01'));
      final repository = OfflineAuthRepository(
        inner: inner,
        cache: cache,
        reachability: const _FakeReachability(),
      );

      final access = await repository.loadCurrentAccess();

      expect(access, _access('usr_01'));
      expect(cache.readAccessState('usr_01'), _access('usr_01'));
    });

    test(
      'network/offline failure returns cached access for same currentHost.id',
      () async {
        final cache = await LocalCache.create();
        await cache.saveAccessState(_access('usr_01'));
        final inner = _FakeAuthRepository(
          current: const HostAuthUser(
            id: 'usr_01',
            email: 'host@example.test',
          ),
          error: const NetworkUnavailableException('socket closed'),
        );
        final repository = OfflineAuthRepository(
          inner: inner,
          cache: cache,
          reachability: const _FakeReachability(),
        );

        final access = await repository.loadCurrentAccess();

        expect(access, _access('usr_01'));
      },
    );

    test(
      'cached access for a different user is not used',
      () async {
        final cache = await LocalCache.create();
        await cache.saveAccessState(_access('usr_01'));
        const networkError = NetworkUnavailableException('socket closed');
        final inner = _FakeAuthRepository(
          current: const HostAuthUser(
            id: 'usr_02',
            email: 'other@example.test',
          ),
          error: networkError,
        );
        final repository = OfflineAuthRepository(
          inner: inner,
          cache: cache,
          reachability: const _FakeReachability(),
        );

        await expectLater(
          repository.loadCurrentAccess(),
          throwsA(same(networkError)),
        );
      },
    );

    test('non-network business errors are rethrown without cache', () async {
      final cache = await LocalCache.create();
      await cache.saveAccessState(_access('usr_01'));
      final businessError = StateError('access denied');
      final inner = _FakeAuthRepository(
        current: const HostAuthUser(
          id: 'usr_01',
          email: 'host@example.test',
        ),
        error: businessError,
      );
      final repository = OfflineAuthRepository(
        inner: inner,
        cache: cache,
        reachability: const _FakeReachability(),
      );

      await expectLater(
        repository.loadCurrentAccess(),
        throwsA(same(businessError)),
      );
    });

    test('signOut calls inner.signOut and clears cached access', () async {
      final cache = await LocalCache.create();
      await cache.saveAccessState(_access('usr_01'));
      final inner = _FakeAuthRepository();
      final repository = OfflineAuthRepository(
        inner: inner,
        cache: cache,
        reachability: const _FakeReachability(),
      );

      await repository.signOut();

      expect(inner.didSignOut, isTrue);
      expect(cache.readAccessState('usr_01'), isNull);
    });

    test('signOut clears cached access when inner signOut throws', () async {
      final cache = await LocalCache.create();
      await cache.saveAccessState(_access('usr_01'));
      final signOutError = StateError('sign out failed');
      final inner = _FakeAuthRepository(signOutError: signOutError);
      final repository = OfflineAuthRepository(
        inner: inner,
        cache: cache,
        reachability: const _FakeReachability(),
      );

      await expectLater(repository.signOut(), throwsA(same(signOutError)));

      expect(inner.didSignOut, isTrue);
      expect(cache.readAccessState('usr_01'), isNull);
    });

    test(
      'signOut preserves inner error when cache clear also throws',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final cacheClearError = StateError('cache clear failed');
        final cache = _ThrowingClearAccessCache(
          preferences,
          cacheClearError,
        );
        final signOutError = StateError('sign out failed');
        final inner = _FakeAuthRepository(signOutError: signOutError);
        final repository = OfflineAuthRepository(
          inner: inner,
          cache: cache,
          reachability: const _FakeReachability(),
        );

        await expectLater(repository.signOut(), throwsA(same(signOutError)));

        expect(inner.didSignOut, isTrue);
      },
    );
  });
}

MosaicAccessState _access(String userId) {
  return MosaicAccessState(
    userId: userId,
    isActive: true,
    events: const [
      MosaicAccessEvent(
        eventId: 'evt_01',
        title: 'Friday Night Mahjong',
        role: MosaicAccessRole.owner,
      ),
    ],
  );
}

class _FakeReachability implements NetworkReachability {
  const _FakeReachability();

  @override
  Future<bool> isReachable() async => true;

  @override
  bool isNetworkException(Object error) {
    return error is NetworkUnavailableException;
  }
}

class _ThrowingClearAccessCache extends LocalCache {
  _ThrowingClearAccessCache(super.preferences, this.clearError);

  final Object clearError;

  @override
  Future<void> clearAccessState() async {
    throw clearError;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    HostAuthUser? current,
    MosaicAccessState? access,
    this.error,
    this.signOutError,
  })  : current = current ??
            const HostAuthUser(id: 'usr_01', email: 'host@example.test'),
        access = access ?? _access('usr_01');

  HostAuthUser? current;
  MosaicAccessState access;
  Object? error;
  Object? signOutError;
  bool didSignOut = false;

  @override
  HostAuthUser? get currentHost => current;

  @override
  Stream<HostAuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<MosaicAccessState> loadCurrentAccess() async {
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return access;
  }

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) {
    throw StateError('signInWithPassword is not used by this test fake.');
  }

  @override
  Future<void> sendEmailOtp({required String email}) {
    throw StateError('sendEmailOtp is not used by this test fake.');
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) {
    throw StateError('verifyEmailOtp is not used by this test fake.');
  }

  @override
  Future<void> signOut() async {
    didSignOut = true;
    current = null;
    final thrown = signOutError;
    if (thrown != null) {
      throw thrown;
    }
  }
}
