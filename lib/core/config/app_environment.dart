import 'package:meta/meta.dart';

@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppEnvironment.fromMap(Map<String, String> values) {
    final rawUrl = values['SUPABASE_URL']?.trim();
    final rawPublishableKey = values['SUPABASE_PUBLISHABLE_KEY']?.trim();

    if (rawUrl == null || rawUrl.isEmpty) {
      throw ArgumentError('SUPABASE_URL is required.');
    }

    if (rawPublishableKey == null || rawPublishableKey.isEmpty) {
      throw ArgumentError('SUPABASE_PUBLISHABLE_KEY is required.');
    }

    final parsedUrl = Uri.tryParse(rawUrl);
    if (parsedUrl == null || !parsedUrl.hasScheme || !parsedUrl.hasAuthority) {
      throw ArgumentError('SUPABASE_URL must be an absolute URL.');
    }

    return AppEnvironment(
      supabaseUrl: parsedUrl,
      supabasePublishableKey: rawPublishableKey,
    );
  }

  final Uri supabaseUrl;
  final String supabasePublishableKey;
}
