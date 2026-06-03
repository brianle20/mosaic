import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk tournament table start migration defines synchronized RPC', () {
    final migration = File(
      'supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, contains('target_event_id uuid'));
    expect(sql, contains('returns setof public.table_sessions'));
    expect(sql, contains('language plpgsql'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(
      sql,
      contains(
        "perform app_private.require_event_for_phase_scoring(target_event_id, 'tournament');",
      ),
    );
    expect(
        sql, isNot(contains('perform app_private.require_event_for_scoring')));
    expect(sql, contains('bulk_started_at timestamptz := now();'));
    expect(
        sql, contains('current_round public.event_tournament_rounds%rowtype;'));
    expect(sql, contains('current_round.status in (\'seating\', \'active\')'));
    expect(sql, contains('limit 1\n  for update;'));
    expect(sql, contains('assignment.status = \'active\''));
    expect(
      sql,
      contains(
        'where assignment.event_id = target_event_id\n'
        '      and assignment.event_table_id = table_row.id\n'
        '      and assignment.status = \'active\';',
      ),
    );
    expect(sql, contains('array_length(assignment_rows, 1) between 2 and 4'));
    expect(
      sql,
      contains(
        'assignment_rows[assignment_index].seat_index <> assignment_index - 1',
      ),
    );
    expect(sql, contains('guest.attendance_status <> \'checked_in\''));
    expect(sql, contains("existing_session.status in ('active', 'paused')"));
    expect(sql, contains('existing_session.event_table_id = table_row.id'));
    expect(sql, contains('seat.event_guest_id = assignment.event_guest_id'));
    expect(sql, contains('table_row.default_ruleset_id'));
    expect(
      sql,
      contains(
        'order by table_candidate.display_order asc,\n'
        '      table_candidate.label asc,\n'
        '      table_candidate.id asc',
      ),
    );
    expect(sql, contains('session_number_for_table'));
    expect(sql, contains('tournament_round_id'));
    expect(sql, contains('assignment_round'));
    expect(sql, contains('started_at'));
    expect(sql, contains('bulk_started_at'));
    expect(sql, contains('started_by_user_id'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains("status = 'active'"));
    expect(sql, contains('insert into public.table_session_seats'));
    expect(
        sql,
        contains(
            "initial_winds text[] := array['east', 'south', 'west', 'north'];"));
    expect(
        sql,
        contains(
            'initial_winds[assignment_rows[assignment_index].seat_index + 1]'));
    expect(sql, isNot(contains('created_session_count')));
    expect(sql, contains('if exists ('));
    expect(sql,
        contains('started_session.tournament_round_id = current_round.id'));
    expect(sql, contains("started_session.scoring_phase = 'tournament'"));
    expect(
        sql, isNot(contains("started_session.status in ('active', 'paused')")));
    expect(sql, contains('started_at = coalesce(started_at, bulk_started_at)'));
    expect(
      sql,
      contains(
        'grant execute on function public.start_current_tournament_round_sessions(uuid)',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });

  test(
    'bulk start allows short current-round tables while normal recalc still assumes four seats',
    () {
      final bulkStartMigration = File(
        'supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql',
      );
      final latestRecalcMigration = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.readAsStringSync().contains(
              'create or replace function app_private.recalculate_session_unowned'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

      expect(bulkStartMigration.existsSync(), isTrue);
      expect(latestRecalcMigration, isNotEmpty);

      final bulkStartSql = bulkStartMigration.readAsStringSync();
      final latestRecalcSql = latestRecalcMigration.last.readAsStringSync();

      expect(
        bulkStartSql,
        contains('array_length(assignment_rows, 1) between 2 and 4'),
      );
      expect(
        latestRecalcSql,
        contains('array_length(seat_guest_ids, 1) <> 4'),
      );
    },
  );
}
