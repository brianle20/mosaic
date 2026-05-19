import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('update cover entry migration adds edit RPC and audit summary', () {
    final migration = File(
      'supabase/migrations/20260518100000_update_cover_entry.sql',
    ).readAsStringSync();

    expect(migration, contains('public.update_cover_entry'));
    expect(migration, contains('target_cover_entry_id uuid'));
    expect(migration, contains('app_private.require_owned_guest'));
    expect(migration, contains('update public.guest_cover_entries'));
    expect(migration, contains("when target_method = 'refund' then -abs"));
    expect(migration, contains('cover_status = next_cover_status'));
    expect(migration, contains('app_private.insert_audit_log'));
    expect(migration, contains("'guest_cover_entry'"));
    expect(migration, contains("'update'"));
    expect(migration, contains('Updated cover entry: %s %s'));
    expect(migration, contains('select pg_notify'));
  });
}
