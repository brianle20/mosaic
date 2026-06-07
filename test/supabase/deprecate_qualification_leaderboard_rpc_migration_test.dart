import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualification leaderboard RPC is no longer client-callable', () {
    final migrationFile = File(
      'supabase/migrations/20260606160000_deprecate_qualification_leaderboard_rpc.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains(
        'revoke all on function public.get_event_qualification_leaderboard',
      ),
    );
    expect(sql, contains(') from public;'));
    expect(sql, contains(') from anon;'));
    expect(sql, contains(') from authenticated;'));
    expect(sql, isNot(contains('drop function')));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
