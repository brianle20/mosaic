import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('magic link template sends an email code instead of a link', () {
    final config = File('supabase/config.toml').readAsStringSync();
    final template = File(
      'supabase/templates/magic_link.html',
    ).readAsStringSync();

    expect(config, contains('[auth.email.template.magic_link]'));
    expect(config, contains('otp_length = 6'));
    expect(config,
        contains('content_path = "./supabase/templates/magic_link.html"'));
    expect(template, contains('{{ .Token }}'));
    expect(template, isNot(contains('{{ .ConfirmationURL }}')));
  });
}
