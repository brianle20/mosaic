import 'package:mosaic/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static Future<void> initialize(SupabaseConfig config) async {
    if (_initialized) {
      return;
    }

    await Supabase.initialize(
      url: config.url,
      anonKey: config.publishableKey,
    );
    _initialized = true;
  }
}
