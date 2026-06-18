import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class OfflineAuthRepository implements AuthRepository {
  const OfflineAuthRepository({
    required this.inner,
    required this.cache,
    required this.reachability,
  });

  final AuthRepository inner;
  final LocalCache cache;
  final NetworkReachability reachability;

  @override
  HostAuthUser? get currentHost => inner.currentHost;

  @override
  Stream<HostAuthUser?> authStateChanges() => inner.authStateChanges();

  @override
  Future<MosaicAccessState> loadCurrentAccess() async {
    try {
      final access = await inner.loadCurrentAccess();
      if (access.userId != null) {
        await cache.saveAccessState(access);
      }
      return access;
    } catch (error) {
      final host = currentHost;
      if (host != null && reachability.isNetworkException(error)) {
        final cached = cache.readAccessState(host.id);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    }
  }

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) {
    return inner.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> sendEmailOtp({required String email}) {
    return inner.sendEmailOtp(email: email);
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) {
    return inner.verifyEmailOtp(email: email, code: code);
  }

  @override
  Future<void> signOut() async {
    Object? signOutError;
    StackTrace? signOutStackTrace;

    try {
      await inner.signOut();
    } catch (error, stackTrace) {
      signOutError = error;
      signOutStackTrace = stackTrace;
    }

    try {
      await cache.clearAccessState();
    } catch (_) {
      if (signOutError == null) {
        rethrow;
      }
    }

    if (signOutError != null) {
      Error.throwWithStackTrace(signOutError, signOutStackTrace!);
    }
  }
}
