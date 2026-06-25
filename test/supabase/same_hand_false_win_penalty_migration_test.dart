import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260624120000_same_hand_false_win_penalties.sql';

  String migration() => File(migrationPath).readAsStringSync();

  test('same-hand false win migration adds penalty table and uniqueness', () {
    final sql = migration();

    expect(
      sql,
      contains('create table if not exists public.hand_false_win_penalties'),
    );
    expect(
      sql,
      contains(
          'table_session_id uuid not null references public.table_sessions'),
    );
    expect(sql, contains('hand_result_id uuid references public.hand_results'));
    expect(sql, contains('client_mutation_id uuid'));
    expect(sql, contains('hand_false_win_penalties_client_mutation_id_unique'));
    expect(
      sql,
      contains('on public.hand_false_win_penalties (client_mutation_id)'),
    );
    expect(sql, contains('where client_mutation_id is not null'));
    expect(sql,
        contains('entered_by_user_id uuid not null references public.users'));
    expect(
      sql,
      contains(
        'hand_false_win_penalty_id uuid references public.hand_false_win_penalties',
      ),
    );
    expect(sql, contains("status text not null default 'pending'"));
    expect(
        sql, contains("check (status in ('pending', 'attached', 'voided'))"));
    expect(sql, contains('hand_false_win_penalties_pending_seat_unique'));
    expect(sql, contains("where status = 'pending'"));
    expect(sql, contains('hand_false_win_penalties_attached_seat_unique'));
    expect(sql, contains("where status = 'attached'"));
  });

  test('same-hand false win migration adds record penalty rpc', () {
    final sql = migration();
    final functionSql =
        _extractFunction(sql, 'public.record_false_win_penalty');

    expect(
      sql,
      contains('create or replace function public.record_false_win_penalty'),
    );
    expect(sql, contains('target_table_session_id uuid'));
    expect(sql, contains('target_penalty_seat_index integer'));
    expect(
      functionSql,
      contains('target_client_mutation_id uuid default null'),
    );
    expect(
      functionSql,
      contains('target_expected_recorded_hand_count integer default null'),
    );
    expect(
      functionSql,
      contains('target_expected_last_recorded_hand_id uuid default null'),
    );
    expect(
      sql,
      contains('app_private.require_owned_session(target_table_session_id)'),
    );
    expect(
      functionSql,
      contains(
        'from public.table_sessions\n  where id = session_row.id\n  for update',
      ),
    );
    expect(functionSql, contains('existing_idempotent_penalty'));
    expect(
      functionSql,
      contains('client_mutation_id = target_client_mutation_id'),
    );
    expect(
      functionSql,
      contains('return existing_idempotent_penalty'),
    );
    expect(
      functionSql,
      contains('Client mutation id belongs to a different session.'),
    );
    expect(functionSql, contains('target_expected_recorded_hand_count'));
    expect(functionSql, contains('target_expected_last_recorded_hand_id'));
    expect(functionSql, contains('Current session hand count has changed.'));
    expect(functionSql, contains('Current last hand has changed.'));
    expect(functionSql, contains("hint = 'offline_sync_conflict'"));
    expect(sql, contains("session_row.status <> 'active'"));
    expect(sql, contains('False win caller seat must be occupied.'));
    expect(sql, contains('False win caller already has a pending penalty.'));
    expect(
      sql,
      contains('app_private.ruleset_base_points(session_row.ruleset_id, 6)'),
    );
    expect(
      functionSql,
      contains('app_private.refresh_event_score_totals(session_row.event_id)'),
    );
    expect(sql, contains("to_jsonb(array['false_win_penalty']::text[])"));
    expect(
      functionSql,
      contains('seat.seat_index = target_penalty_seat_index'),
    );
    expect(
      functionSql,
      contains('seat.seat_index <> target_penalty_seat_index'),
    );
    expect(functionSql, contains('hand_false_win_penalty_id'));
    expect(functionSql, contains('inserted_penalty.id'));
    expect(functionSql, contains('client_mutation_id'));
    expect(functionSql, contains('target_client_mutation_id'));
    expect(
      sql,
      contains(
        'grant execute on function public.record_false_win_penalty(uuid, integer, text, uuid, integer, uuid)',
      ),
    );
  });

  test(
      'same-hand false win migration attaches pending penalties on final outcome',
      () {
    final sql = migration();
    final functionSql = _extractFunction(sql, 'public.record_hand_result');

    expect(sql, contains('app_private.attach_pending_false_win_penalties'));
    expect(sql, contains('public.record_hand_result'));
    expect(sql, contains("target_result_type = 'win'"));
    expect(sql, contains('False win callers cannot win this hand.'));
    expect(sql, contains("target_result_type in ('win', 'washout')"));
    expect(sql, contains("set status = 'attached'"));
    expect(functionSql, contains('hand_false_win_penalty_id in ('));
    expect(functionSql, isNot(contains('payer_event_guest_id in (')));
    expect(functionSql, isNot(contains('payee_event_guest_id in (')));
    expect(
      functionSql,
      isNot(contains(
          "multiplier_flags_json = to_jsonb(array['false_win_penalty']::text[])")),
    );
  });

  test('same-hand false win migration keeps settlement insert shapes aligned',
      () {
    final sql = migration();
    final functionSql =
        _extractFunction(sql, 'app_private.recalculate_session_unowned');

    expect(
      functionSql,
      contains('''
        insert into public.hand_settlements (
          hand_result_id,
          hand_false_win_penalty_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          null,
          payer_guest_id,
          payee_guest_id,
          amount_points_value,
          to_jsonb(multiplier_flags)
        );'''),
    );
    expect(
      functionSql,
      contains('''
        insert into public.hand_settlements (
          hand_result_id,
          hand_false_win_penalty_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          penalty_row.id,
          payer_guest_id,
          payee_guest_id,
          penalty_base_points_value,
          to_jsonb(array['false_win_penalty']::text[])
        );'''),
    );
  });

  test('same-hand false win migration exposes pending penalty settlements', () {
    final sql = migration();

    expect(
      sql,
      contains(
          'drop policy if exists hand_settlements_owner_or_staff_read on public.hand_settlements'),
    );
    expect(sql, contains('create policy hand_settlements_owner_or_staff_read'));
    expect(sql, contains('from public.hand_false_win_penalties as penalty'));
    expect(sql, contains('penalty.id = hand_false_win_penalty_id'));
    expect(sql, contains('join public.table_sessions as session'));
    expect(sql, contains('session.id = penalty.table_session_id'));
    expect(sql, contains('app_private.can_view_event(session.event_id)'));
  });

  test('same-hand false win penalties are readable by event viewers', () {
    final sql = migration();
    final policySql = _extractPolicy(
      sql,
      'hand_false_win_penalties_owner_select',
    );

    expect(policySql, contains('app_private.can_view_event(session.event_id)'));
    expect(
      policySql,
      isNot(contains('app_private.can_score_tournament(session.event_id)')),
    );
  });

  test('same-hand false win migration includes pending penalties in totals',
      () {
    final sql = migration();
    final functionSql =
        _extractFunction(sql, 'app_private.refresh_event_score_totals');

    expect(functionSql, contains('hand_false_win_penalty_id'));
    expect(
      functionSql,
      contains('join public.hand_false_win_penalties as penalty'),
    );
    expect(
      functionSql,
      contains('penalty.id = settlement.hand_false_win_penalty_id'),
    );
    expect(functionSql, contains("penalty.status = 'pending'"));
    expect(functionSql, contains('settlement.hand_result_id is null'));
    expect(functionSql, contains("hand_result.status = 'recorded'"));
    expect(functionSql, contains('penalty_session.event_id = target_event_id'));
  });

  test(
      'same-hand false win migration preserves expired round completion trigger',
      () {
    final sql = migration();

    expect(sql, contains('round_time_completed boolean := false'));
    expect(sql, contains('session_row.started_at + round_time_limit_duration'));
    expect(sql, contains('completion_flag := true'));
    expect(sql, contains("when round_time_completed then 'completed'"));
  });

  test(
      'same-hand false win migration voids attached penalties with voided hand',
      () {
    final sql = migration();

    expect(sql, contains('public.void_hand_result'));
    expect(sql, contains("status = 'voided'"));
    expect(sql, contains('hand_result_id = existing_hand.id'));
  });
}

String _extractFunction(String sql, String functionName) {
  final start = sql.indexOf('create or replace function $functionName');
  expect(start, isNonNegative, reason: 'missing $functionName');
  final rest = sql.substring(start);
  final end = rest.indexOf('\n\$\$;');
  expect(end, isNonNegative, reason: 'unterminated $functionName');
  return rest.substring(0, end);
}

String _extractPolicy(String sql, String policyName) {
  final start = sql.indexOf('create policy $policyName');
  expect(start, isNonNegative, reason: 'missing $policyName');
  final rest = sql.substring(start);
  final end = rest.indexOf('\n);');
  expect(end, isNonNegative, reason: 'unterminated $policyName');
  return rest.substring(0, end);
}
