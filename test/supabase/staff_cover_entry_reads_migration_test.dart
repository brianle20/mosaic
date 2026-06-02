import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cover entry read RPC allows assigned staff to view event guests', () {
    final sql = File(
      'supabase/migrations/20260531114000_allow_staff_cover_entry_reads.sql',
    ).readAsStringSync();

    expect(sql, contains('public.list_guest_cover_entries'));
    expect(sql, contains('app_private.can_view_event(guest.event_id)'));
    expect(sql, isNot(contains('app_private.require_owned_guest')));
    expect(
      sql,
      contains(
        'grant execute on function public.list_guest_cover_entries(uuid) to authenticated',
      ),
    );
  });
}
