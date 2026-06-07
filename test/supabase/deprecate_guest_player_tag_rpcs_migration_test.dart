import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest player tag RPCs are no longer client executable', () {
    final migrationFile = File(
      'supabase/migrations/20260606170000_deprecate_guest_player_tag_rpcs.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    for (final functionName in [
      'assign_guest_tag',
      'replace_guest_tag',
      'resolve_guest_by_active_tag',
    ]) {
      expect(sql, contains('revoke all on function public.$functionName'));
      expect(sql, contains(') from public;'));
      expect(sql, contains(') from anon;'));
      expect(sql, contains(') from authenticated;'));
      expect(sql, contains('grant execute on function public.$functionName'));
      expect(sql, contains(') to service_role;'));
    }

    expect(sql, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
