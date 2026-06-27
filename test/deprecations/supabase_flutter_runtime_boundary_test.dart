import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime app code does not import the Supabase Flutter wrapper', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in libFiles) {
      final source = file.readAsStringSync();

      expect(
        source,
        isNot(contains('package:supabase_flutter/supabase_flutter.dart')),
        reason:
            '${file.path} should use package:supabase/supabase.dart or SupabaseBootstrap instead.',
      );
    }
  });

  test('pubspec uses the plain Supabase client for runtime code', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('\n  supabase:'));
    expect(pubspec, isNot(contains('\n  supabase_flutter:')));
  });
}
