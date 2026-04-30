import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('table tag binding creates unknown table tags and rejects player tags',
      () {
    final migration = File(
      'supabase/migrations/20260411193000_tables_and_session_start.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('create or replace function app_private.ensure_table_tag'),
    );
    expect(migration, contains('default_tag_type,\n      display_label'));
    expect(migration, contains("'table',\n      scanned_display_label"));
    expect(migration, contains("if tag_row.default_tag_type = 'player' then"));
    expect(
      migration,
      contains('A player tag cannot be rebound as a table tag.'),
    );
    expect(migration,
        contains('create or replace function public.bind_table_tag'));
    expect(migration, contains('tag_row := app_private.ensure_table_tag'));
  });
}
