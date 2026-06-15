import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copy event migration clones setup and omits live history', () {
    final migrationFile = File(
      'supabase/migrations/20260524220000_copy_event_for_testing.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('copy_event_for_testing'));
    expect(migration, contains('lifecycle_status'));
    expect(migration, contains("'draft'"));
    expect(migration, contains('checkin_open'));
    expect(migration, contains('scoring_open'));
    expect(migration, contains('false'));
    expect(migration, contains('current_scoring_phase'));
    expect(migration, contains("'qualification'"));
    expect(migration, contains('insert into public.event_guests'));
    expect(migration, contains('attendance_status'));
    expect(migration, contains("'expected'"));
    expect(migration, contains('tournament_status'));
    expect(migration, contains("'open_play_only'"));
    expect(migration, contains('checked_in_at'));
    expect(migration, contains('null'));
    expect(migration, contains('insert into public.event_tables'));
    expect(migration, contains('insert into public.prize_plans'));
    expect(migration, contains('insert into public.prize_tiers'));
    expect(migration, isNot(contains('event_guest_tag_assignments')));
    expect(migration, isNot(contains('table_sessions')));
    expect(migration, isNot(contains('hand_results')));
    expect(migration, isNot(contains('event_score_totals')));
    expect(migration, isNot(contains('event_tournament_rounds')));
    expect(migration, isNot(contains('prize_awards')));
  });

  test('latest copy event migration does not copy table tag bindings', () {
    final migrationFile = File(
      'supabase/migrations/20260530093000_copy_event_without_table_tags.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();
    final tableInsert = RegExp(
      r'insert into public\.event_tables \((.*?)\)\s*select(.*?)from public\.event_tables',
      dotAll: true,
    ).firstMatch(migration);

    expect(tableInsert, isNotNull);
    expect(tableInsert!.group(1), isNot(contains('nfc_tag_id')));
    expect(tableInsert.group(2), isNot(contains('event_table.nfc_tag_id')));
  });

  test('latest copy event migration preserves guest tournament status', () {
    final migrationFile = File(
      'supabase/migrations/20260613120000_preserve_copied_event_tournament_status.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();
    final guestInsert = RegExp(
      r'insert into public\.event_guests \((.*?)\)\s*select(.*?)from public\.event_guests',
      dotAll: true,
    ).firstMatch(migration);

    expect(guestInsert, isNotNull);
    expect(guestInsert!.group(1), contains('tournament_status'));
    expect(guestInsert.group(2), contains('guest.tournament_status'));
    expect(guestInsert.group(2), isNot(contains("'open_play_only'")));
  });
}
