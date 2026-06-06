import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'qualification scorer role removal migrates existing staff to event scorer',
      () {
    final migration = File(
      'supabase/migrations/20260606130000_remove_qualification_scorer_role.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql, contains('update public.event_staff_memberships'));
    expect(sql, contains("role = 'event_scorer'"));
    expect(sql, contains("role = 'qualification_scorer'"));
    expect(sql, isNot(contains('archived_at is null')));
    expect(
        sql,
        contains(
            'drop constraint if exists event_staff_memberships_role_check'));
    expect(sql, contains('constraint event_staff_memberships_role_check'));
    expect(sql, contains("check (role = 'event_scorer')"));
    expect(
        sql,
        contains(
            'create or replace function app_private.can_score_qualification'));
    expect(
        sql,
        contains(
            "app_private.event_staff_role(target_event_id, target_user_id) = 'event_scorer'"));
    expect(
        sql,
        contains(
            'create or replace function public.upsert_event_staff_membership'));
    expect(sql, contains("if staff_role <> 'event_scorer' then"));
    expect(
      sql,
      isNot(contains(
        "in ('qualification_scorer', 'event_scorer')",
      )),
    );
  });
}
