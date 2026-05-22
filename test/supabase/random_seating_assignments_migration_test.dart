import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('random seating assignments migration adds schema RPCs and enforcement',
      () {
    final migrationFile = File(
      'supabase/migrations/20260521130000_random_seating_assignments.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('event_seating_assignments'));
    expect(migration, contains('seating_mode'));
    expect(
      migration,
      contains('add column if not exists seating_mode text'),
    );
    expect(
      migration,
      contains("set seating_mode = 'manual'"),
    );
    expect(
      migration,
      contains("alter column seating_mode set default 'random'"),
    );
    expect(
      migration,
      contains('alter column seating_mode set not null'),
    );
    expect(
      migration,
      contains('event_seating_assignments_enforce_same_event'),
    );
    expect(
      migration,
      contains('event_tables_id_event_id_unique'),
    );
    expect(
      migration,
      contains('event_guests_id_event_id_unique'),
    );
    expect(
      migration,
      contains('event_seating_assignments_table_same_event_fk'),
    );
    expect(
      migration,
      contains('foreign key (event_table_id, event_id)'),
    );
    expect(
      migration,
      contains('references public.event_tables (id, event_id)'),
    );
    expect(
      migration,
      contains('event_seating_assignments_guest_same_event_fk'),
    );
    expect(
      migration,
      contains('foreign key (event_guest_id, event_id)'),
    );
    expect(
      migration,
      contains('references public.event_guests (id, event_id)'),
    );
    expect(
      migration,
      contains('event_seating_assignments_active_guest_idx'),
    );
    expect(
      migration,
      contains(
          'on public.event_seating_assignments (event_id, event_guest_id)'),
    );
    expect(
      migration,
      contains('event_seating_assignments_active_table_seat_idx'),
    );
    expect(
      migration,
      contains(
        'on public.event_seating_assignments (event_id, event_table_id, seat_index)',
      ),
    );
    expect(
      migration,
      contains("where status = 'active'"),
    );
    expect(
      migration,
      contains('trigger_event_seating_assignments_enforce_same_event'),
    );
    expect(
      migration,
      contains(
        'Seating assignment table must belong to the same event.',
      ),
    );
    expect(
      migration,
      contains(
        'Seating assignment guest must belong to the same event.',
      ),
    );
    expect(migration, contains('generate_random_seating_assignments'));
    expect(migration, contains('get_event_seating_assignments'));
    expect(migration, contains('clear_event_seating_assignments'));
    expect(migration, contains('validate_random_seating_assignment'));
    expect(
      migration,
      contains('create or replace function public.start_table_session'),
    );
    expect(
      migration,
      contains(
        'The scanned player does not match the random seating assignment.',
      ),
    );
  });
}
