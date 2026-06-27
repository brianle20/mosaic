import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mosaic/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

abstract final class SupabaseBootstrap {
  static bool _initialized = false;
  static SupabaseClient? _client;
  static StreamSubscription<AuthState>? _authSubscription;

  static SupabaseClient get client {
    final client = _client;
    if (client == null) {
      throw StateError(
        'SupabaseBootstrap.initialize must be called before reading client.',
      );
    }
    return client;
  }

  static Future<void> initialize(SupabaseConfig config) async {
    if (_initialized) {
      return;
    }

    WidgetsFlutterBinding.ensureInitialized();
    final preferences = await SharedPreferences.getInstance();
    final sessionKey = _persistSessionKey(config.url);
    final client = SupabaseClient(
      config.url,
      config.publishableKey,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: _SharedPreferencesGotrueAsyncStorage(preferences),
      ),
    );

    _client = client;
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        unawaited(
          preferences.setString(sessionKey, jsonEncode(session.toJson())),
        );
      } else if (data.event == AuthChangeEvent.signedOut) {
        unawaited(preferences.remove(sessionKey));
      }
    });

    final persistedSession = preferences.getString(sessionKey);
    if (persistedSession != null && persistedSession.isNotEmpty) {
      var restoredSession = false;
      try {
        await client.auth.setInitialSession(persistedSession);
        restoredSession = true;
      } on AuthException {
        await preferences.remove(sessionKey);
      } on FormatException {
        await preferences.remove(sessionKey);
      } on TypeError {
        await preferences.remove(sessionKey);
      }

      if (restoredSession) {
        try {
          await client.auth.recoverSession(persistedSession);
        } on Object {
          // Keep the restored session available even when refresh fails offline.
        }
      }
    }

    _initialized = true;
  }

  static String _persistSessionKey(String url) {
    return 'sb-${Uri.parse(url).host.split('.').first}-auth-token';
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _client?.dispose();
    _client = null;
    _initialized = false;
  }
}

class _SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  const _SharedPreferencesGotrueAsyncStorage(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> getItem({required String key}) async {
    return _preferences.getString(key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _preferences.remove(key);
  }

  @override
  Future<void> setItem({
    required String key,
    required String value,
  }) async {
    await _preferences.setString(key, value);
  }
}
