import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remaining player tag helper RPCs are no longer client executable', () {
    final migrationFile = File(
      'supabase/migrations/20260607130000_deprecate_remaining_player_tag_rpcs.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    for (final signature in [
      'public.get_guest_tag_assignment_summary(uuid)',
      'public.register_nfc_tag(text, text, text)',
    ]) {
      expect(sql, contains('revoke all on function $signature'));
      expect(sql, contains('from public;'));
      expect(sql, contains('from anon;'));
      expect(sql, contains('from authenticated;'));
      expect(sql, contains('grant execute on function $signature'));
      expect(sql, contains('to service_role;'));
    }

    expect(sql, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
