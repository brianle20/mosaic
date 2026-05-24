import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bonus round finals migration adds schema RPCs and scoring hooks', () {
    final migrationFile = File(
      'supabase/migrations/20260522130000_bonus_round_finals.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('event_bonus_rounds'));
    expect(migration, contains('event_score_adjustments'));
    expect(migration, contains('assignment_type'));
    expect(migration, contains('bonus_table_role'));
    expect(migration, contains('seed_rank'));
    expect(migration, contains('table_of_champions'));
    expect(migration, contains('table_of_redemption'));
    expect(migration, contains('generate_bonus_round_seating_assignments'));
    expect(migration, contains('apply_bonus_round_champion_award'));
    expect(migration, contains('Finals champion award'));
    expect(
      migration,
      contains('-- exclude bonus sessions from event score totals'),
    );
    expect(
      migration,
      contains('top non-champion event score before champion award'),
    );
    expect(migration, contains('champion_bonus_score_points'));
    expect(migration, contains('champion_top_up_points'));
    expect(migration, contains('bonus_round_id'));
    expect(migration, contains('public.list_event_hand_ledger'));
    expect(migration, contains('session.bonus_round_id'));
    expect(migration, contains('hand_row.bonus_table_role'));
    expect(migration, contains('guest.attendance_status = \'checked_in\''));
    expect(migration, contains('tag.default_tag_type = \'player\''));
    expect(migration, contains('An active bonus round already exists'));
    expect(migration, contains('source_session.bonus_round_id'));
    expect(migration, contains('round_time_limit_effective_at'));
    expect(migration, contains('round_time_limit_duration'));
    expect(migration, contains('round_time_completed'));
    expect(migration, contains("when round_time_completed then 'completed'"));
    expect(
      migration,
      contains(
        'when round_time_completed then coalesce(session_row.ended_at, now())',
      ),
    );
    expect(
      migration,
      contains('East: #4, South: #3, West: #2, North: #1'),
    );
    expect(migration, contains('4th last'));
    expect(migration, contains('3rd last'));
    expect(migration, contains('2nd last'));
    expect(migration, contains('last'));
    expect(
      migration,
      contains('At least eight ranked players are required'),
    );
    expect(
      migration,
      contains('Bonus round tables must be different'),
    );
  });
}
