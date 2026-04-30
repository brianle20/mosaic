import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nfc tag owner migration scopes tag rows to the signed-in host', () {
    final migration = File(
      'supabase/migrations/20260501010000_nfc_tag_owner_rls.sql',
    ).readAsStringSync();

    expect(migration, contains('owner_user_id uuid references public.users'));
    expect(migration,
        contains('drop policy if exists nfc_tags_authenticated_all'));
    expect(migration, contains('create policy nfc_tags_owner_all'));
    expect(migration, contains('using (owner_user_id = auth.uid())'));
    expect(migration, contains('with check (owner_user_id = auth.uid())'));
    expect(migration, contains('nfc_tags_owner_uid_hex_unique'));
    expect(migration, contains('where owner_user_id = auth.uid()'));
    expect(
        migration, contains('perform app_private.require_event_for_scoring'));
  });
}
