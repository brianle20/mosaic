import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assigned table entry migration allows host table entry without scan',
      () {
    final migrationFile = File(
      'supabase/migrations/20260524173500_enter_assigned_table_without_scan.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains(
          'create or replace function public.start_assigned_table_session'),
    );
    expect(migration, contains('scanned_table_uid text'));
    expect(migration, contains('if scanned_table_uid is not null then'));
    expect(
      migration,
      contains('grant execute on function public.start_assigned_table_session'),
    );
  });
}
