import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('future qualification scoring migration defaults new play to tournament',
      () {
    final migration = File(
      'supabase/migrations/20260606120000_remove_future_qualification_scoring.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql, contains('event.archived_at is null'));
    expect(sql, contains("session.scoring_phase = 'qualification'"));
    expect(
      sql,
      contains(
        'Unarchived qualification sessions exist. Archive them or migrate them before removing qualification scoring.',
      ),
    );
    expect(
      sql,
      contains(
        "alter column current_scoring_phase set default 'tournament'",
      ),
    );
    expect(
      sql,
      contains("alter column scoring_phase set default 'tournament'"),
    );
    expect(sql, contains("current_scoring_phase = 'tournament'"));
    expect(sql, contains("current_scoring_phase = 'qualification'"));
    expect(
        sql, contains('update public.event_staff_memberships as membership'));
    expect(sql, contains("role = 'event_scorer'"));
    expect(sql, contains("membership.role = 'qualification_scorer'"));
    expect(sql,
        contains('create or replace function public.copy_event_for_testing'));
    expect(sql, contains("'tournament'"));
    expect(sql,
        isNot(contains("'qualification',\n    source_event.seating_mode")));
    expect(
      sql,
      contains(
          'create or replace function public.upsert_event_staff_membership'),
    );
    expect(sql, contains("if staff_role <> 'event_scorer' then"));
  });
}
