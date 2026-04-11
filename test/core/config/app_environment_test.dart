import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/config/app_environment.dart';

void main() {
  group('AppEnvironment.fromMap', () {
    test('throws when publishable key is missing', () {
      expect(
        () => AppEnvironment.fromMap(const {
          'SUPABASE_URL': 'https://example.supabase.co',
        }),
        throwsArgumentError,
      );
    });
  });
}
