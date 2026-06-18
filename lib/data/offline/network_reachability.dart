import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class NetworkReachability {
  Future<bool> isReachable();

  bool isNetworkException(Object error);
}

class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DefaultNetworkReachability implements NetworkReachability {
  const DefaultNetworkReachability({
    required this.client,
    this.pingTimeout = const Duration(seconds: 3),
  });

  final SupabaseClient client;
  final Duration pingTimeout;

  @override
  Future<bool> isReachable() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty ||
        connectivity.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    try {
      await client.from('events').select('id').limit(1).timeout(pingTimeout);
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
