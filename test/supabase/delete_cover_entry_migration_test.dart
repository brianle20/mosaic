import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete cover entry migration adds delete RPC and audit summary', () {
    final migration = File(
      'supabase/migrations/20260611120000_delete_cover_entry.sql',
    ).readAsStringSync();

    expect(migration, contains('public.delete_cover_entry'));
    expect(migration, contains('target_cover_entry_id uuid'));
    expect(migration, contains('delete from public.guest_cover_entries'));
    expect(migration, contains('cover_status = next_cover_status'));
    expect(migration, contains("'guest_cover_entry'"));
    expect(migration, contains("'delete'"));
    expect(migration, contains('Deleted cover entry: %s %s'));
  });
}
