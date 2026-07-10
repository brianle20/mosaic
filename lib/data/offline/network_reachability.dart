import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase/supabase.dart';

typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();
typedef BackendReachabilityProbe = Future<void> Function();

abstract interface class NetworkReachability {
  Future<bool> isReachable();
  Stream<void> get onReachable;

  bool isNetworkException(Object error);
}

class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DefaultNetworkReachability implements NetworkReachability {
  DefaultNetworkReachability({
    required this.client,
    this.pingTimeout = const Duration(seconds: 3),
    ConnectivityChecker? connectivityChecker,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    BackendReachabilityProbe? backendProbe,
  })  : _connectivityChecker =
            connectivityChecker ?? Connectivity().checkConnectivity,
        _connectivityChanges =
            connectivityChanges ?? Connectivity().onConnectivityChanged,
        _backendProbe = backendProbe;

  final SupabaseClient client;
  final Duration pingTimeout;
  final ConnectivityChecker _connectivityChecker;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final BackendReachabilityProbe? _backendProbe;

  @override
  Stream<void> get onReachable => _connectivityChanges
      .asyncMap((_) => isReachable())
      .distinct()
      .where((reachable) => reachable)
      .map((_) {});

  @override
  Future<bool> isReachable() async {
    final connectivity = await _connectivityChecker();
    if (connectivity.isEmpty ||
        connectivity.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    try {
      final probe = _backendProbe;
      if (probe != null) {
        await probe().timeout(pingTimeout);
      } else {
        await client.from('events').select('id').limit(1).timeout(pingTimeout);
      }
      return true;
    } catch (error) {
      return !isNetworkException(error);
    }
  }

  @override
  bool isNetworkException(Object error) {
    if (error is NetworkUnavailableException || error is TimeoutException) {
      return true;
    }

    if (error is PostgrestException) {
      return false;
    }

    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('connection failed') ||
        message.contains('failed host lookup') ||
        message.contains('host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('xmlhttprequest');
  }
}
