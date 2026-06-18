import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('performance hot path migration adds indexes for event-day reads', () {
    final migrationFile = File(
      'supabase/migrations/20260615140000_performance_hot_path_indexes.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains('create index if not exists hand_settlements_payee_guest_idx'),
    );
    expect(
      sql,
      contains('on public.hand_settlements (payee_event_guest_id)'),
    );
    expect(
      sql,
      contains('create index if not exists hand_settlements_payer_guest_idx'),
    );
    expect(
      sql,
      contains('on public.hand_settlements (payer_event_guest_id)'),
    );
    expect(
      sql,
      contains('create index if not exists table_sessions_event_started_idx'),
    );
    expect(
        sql, contains('on public.table_sessions (event_id, started_at desc)'));
    expect(
      sql,
      contains('create index if not exists event_tables_event_display_idx'),
    );
    expect(
      sql,
      contains('on public.event_tables (event_id, display_order, label)'),
    );
    expect(
      sql,
      contains('create index if not exists event_guests_event_display_idx'),
    );
    expect(
      sql,
      contains('on public.event_guests (event_id, display_name)'),
    );
    expect(
      sql,
      contains('create index if not exists guest_cover_entries_guest_date_idx'),
    );
    expect(
      sql,
      contains(
        'on public.guest_cover_entries '
        '(event_guest_id, transaction_on desc, created_at desc, id desc)',
      ),
    );
    expect(
      sql,
      contains(
          'create index if not exists events_owner_unarchived_created_idx'),
    );
    expect(
      sql,
      contains('on public.events (owner_user_id, created_at desc)'),
    );
    expect(sql, contains('where archived_at is null'));
    expect(
      sql,
      contains('create index if not exists hand_results_session_hand_idx'),
    );
    expect(
      sql,
      contains('on public.hand_results (table_session_id, hand_number)'),
    );
  });
}
