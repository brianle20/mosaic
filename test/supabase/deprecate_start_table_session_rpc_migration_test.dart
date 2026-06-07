import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy start_table_session wrapper is no longer client executable', () {
    final migrationFile = File(
      'supabase/migrations/20260607120000_deprecate_start_table_session_rpc.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    const signature = 'public.start_table_session(uuid, text, text, text, text, text)';
    expect(sql, contains('revoke all on function $signature from public;'));
    expect(sql, contains('revoke all on function $signature from anon;'));
    expect(
      sql,
      contains('revoke all on function $signature from authenticated;'),
    );
    expect(sql, contains('grant execute on function $signature to service_role;'));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
