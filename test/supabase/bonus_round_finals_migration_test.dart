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

  test('finals sudden death migration adds tiebreak state and RPCs', () {
    final migrationFile = File(
      'supabase/migrations/20260526130000_finals_sudden_death.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('champion_resolution_method'));
    expect(migration, contains('sudden_death_status'));
    expect(migration, contains('sudden_death_table_id'));
    expect(migration, contains('sudden_death_session_id'));
    expect(migration, contains('table_of_champions_sudden_death'));
    expect(migration, contains('public.get_bonus_round_state'));
    expect(
      migration,
      contains(
        'create or replace function public.get_bonus_round_state(\n'
        '  target_event_id uuid\n'
        ')',
      ),
    );
    expect(migration, contains('public.start_bonus_round_sudden_death'));
    expect(
      migration,
      contains(
        'create or replace function public.start_bonus_round_sudden_death(\n'
        '  target_event_id uuid,\n'
        '  sudden_death_table_id uuid\n'
        ')',
      ),
    );
    expect(migration, isNot(contains('target_bonus_round_id uuid')));
    expect(migration, contains('app_private.apply_bonus_round_champion_award'));
    expect(migration, contains('tied_top_players'));
    expect(migration, contains("'bonus_round_id', bonus_round_row.id"));
    expect(migration, contains("'event_id', bonus_round_row.event_id"));
    expect(migration, contains("'status', bonus_round_row.status"));
    expect(
      migration,
      contains("'champions_table_id', bonus_round_row.champions_table_id"),
    );
    expect(
      migration,
      contains("'redemption_table_id', bonus_round_row.redemption_table_id"),
    );
    expect(
      migration,
      contains(
        "'champion_event_guest_id', bonus_round_row.champion_event_guest_id",
      ),
    );
    expect(
      migration,
      contains(
        "'champion_bonus_score_points', "
        'bonus_round_row.champion_bonus_score_points',
      ),
    );
    expect(
      migration,
      contains(
        "'champion_top_up_points', bonus_round_row.champion_top_up_points",
      ),
    );
    expect(
      migration,
      contains(
        "'champion_award_points', bonus_round_row.champion_award_points",
      ),
    );
    expect(
      migration,
      contains('where bonus_round.event_id = target_event_id'),
    );
    expect(
      migration,
      contains("bonus_round.sudden_death_status = 'required'"),
    );
    expect(migration, contains('sudden death required'));
    expect(migration, contains('result_type = \'win\''));
    expect(migration, contains('result_type = \'washout\''));
    expect(migration, contains('order by random()'));
    expect(migration,
        contains('create or replace function public.complete_event'));
    expect(
      migration,
      contains("bonus_round.sudden_death_status in ('required', 'active')"),
    );
    expect(
      migration,
      contains(
        'Resolve Table of Champions sudden death before completing the event.',
      ),
    );
    expect(
      migration,
      isNot(contains(
        'order by session_bonus_scores.bonus_score_points desc,\n'
        '    session_bonus_scores.seed_rank asc nulls last',
      )),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.get_bonus_round_state(uuid)',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.start_bonus_round_sudden_death(uuid, uuid)',
      ),
    );
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });

  test('sudden death RPC qualifies bonus round id updates', () {
    final originalMigration = File(
      'supabase/migrations/20260526130000_finals_sudden_death.sql',
    ).readAsStringSync();
    final fixMigrationFile = File(
      'supabase/migrations/20260530200000_fix_sudden_death_ambiguous_id.sql',
    );

    expect(
      originalMigration,
      isNot(contains('where id = bonus_round_row.id;')),
    );
    expect(
      originalMigration,
      contains('where bonus_round.id = bonus_round_row.id;'),
    );
    expect(fixMigrationFile.existsSync(), isTrue);

    final fixMigration = fixMigrationFile.readAsStringSync();

    expect(
      fixMigration,
      contains(
          'create or replace function public.start_bonus_round_sudden_death'),
    );
    expect(
      fixMigration,
      isNot(contains('where id = bonus_round_row.id;')),
    );
    expect(
      fixMigration,
      contains('where bonus_round.id = bonus_round_row.id;'),
    );
    expect(
        fixMigration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
