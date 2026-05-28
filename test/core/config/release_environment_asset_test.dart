import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release builds bundle only the mobile-safe environment asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains(RegExp(r'^\s*-\s+\.env\s*$', multiLine: true))));
    expect(pubspec, contains(RegExp(r'^\s*-\s+\.env\.mobile\s*$', multiLine: true)));
  });

  test('mobile environment asset does not contain private database credentials', () {
    final mobileEnvironment = File('.env.mobile').readAsStringSync();

    expect(mobileEnvironment, contains('SUPABASE_URL='));
    expect(mobileEnvironment, contains('SUPABASE_PUBLISHABLE_KEY='));
    expect(mobileEnvironment, isNot(contains('SUPABASE_DB_PASSWORD')));
  });

  test('app startup loads the mobile-safe environment asset', () {
    final mainEntrypoint = File('lib/main.dart').readAsStringSync();

    expect(mainEntrypoint, contains("dotenv.load(fileName: '.env.mobile')"));
    expect(mainEntrypoint, isNot(contains("dotenv.load(fileName: '.env')")));
  });
}
