import 'package:meta/meta.dart';
import 'package:mosaic/core/config/app_environment.dart';

@immutable
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
  });

  factory SupabaseConfig.fromEnvironment(AppEnvironment environment) {
    return SupabaseConfig(
      url: environment.supabaseUrl.toString(),
      publishableKey: environment.supabasePublishableKey,
    );
  }

  final String url;
  final String publishableKey;
}
