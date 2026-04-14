import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/live_backend_assertions.dart';
import 'support/live_cleanup.dart';
import 'support/live_fixture_factory.dart';
import 'support/live_fixture_state.dart';
import 'support/live_test_harness.dart';
import 'support/live_test_ids.dart';

void main() {
  ensureIntegrationTestBinding();

  testWidgets('live_mutation_edit_hand_recalculates_leaderboard',
      (tester) async {
    final data = _ScenarioData.create('mutation_edit_hand');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(data.normalizedTagUids);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(
        tester,
        tableTagUid: data.tableTagUid,
      );
      final sessionId = await startSessionViaUi(
        tester,
        eventId: state.eventId!,
        tableId: tableId,
        tableTagUid: data.tableTagUid,
        playerTagUids: data.playerTagUids,
      );

      await recordDiscardHandViaUi(
        tester,
        winnerLabel: '${data.guestNames[2]} (West)',
        discarderLabel: '${data.guestNames[0]} (East)',
        fanCount: '2',
      );
      await recordSelfDrawHandViaUi(
        tester,
        winnerLabel: '${data.guestNames[1]} (South)',
        fanCount: '1',
      );

      final before = await loadLeaderboard(state.eventId!);
      expect(before, isNotEmpty);

      await pumpUntilVisible(tester, find.text('Hand 1'));
      await tester.tap(find.text('Hand 1'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Edit Hand'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'),
        '4',
      );
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Scoring Preview'));
      await tester.tap(find.text('Save Hand'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Session Detail'));

      final after = await loadLeaderboard(state.eventId!);
      expect(after, isNotEmpty);
      expect(after.first['total_points'], isNot(before.first['total_points']));

      final hands = await Supabase.instance.client
          .from('hand_results')
          .select('hand_number, fan_count, status')
          .eq('table_session_id', sessionId)
          .order('hand_number', ascending: true);
      expect(hands.first['fan_count'], 4);
      expect(hands.first['status'], 'recorded');
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_scoring_closed_blocks_session_start', (tester) async {
    final data = _ScenarioData.create('block_scoring_closed');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(data.normalizedTagUids);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(
        tester,
        tableTagUid: data.tableTagUid,
      );

      await tester.tap(find.text('Start Session').first);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Scan Table Tag'));

      await scanSessionStepViaUi(tester, data.tableTagUid, 'Scan Table Tag');
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[0],
        'Scan East Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[1],
        'Scan South Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[2],
        'Scan West Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[3],
        'Scan North Player Tag',
      );

      await pumpUntilVisible(tester, find.text('Review Session'));
      await tester.tap(find.text('Confirm Start Session'));
      await tester.pumpAndSettle();

      final sessions = await Supabase.instance.client
          .from('table_sessions')
          .select('id')
          .eq('event_id', state.eventId!)
          .eq('event_table_id', tableId);
      expect(sessions, isEmpty);
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_finalize_with_active_session', (tester) async {
    final data = _ScenarioData.create('block_finalize_active_session');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(data.normalizedTagUids);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.tableTagUid);
      await startSessionViaUi(
        tester,
        eventId: state.eventId!,
        tableId: tableId,
        tableTagUid: data.tableTagUid,
        playerTagUids: data.playerTagUids,
      );

      await tapBack(tester);
      await tester.pumpAndSettle();
      await tapBack(tester);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Complete Event'));

      await tester.tap(find.text('Complete Event'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Complete Event'));

      final eventRow = await Supabase.instance.client
          .from('events')
          .select('lifecycle_status')
          .eq('id', state.eventId!)
          .single();
      expect(eventRow['lifecycle_status'], 'active');
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_finalize_without_locked_prizes_when_plan_exists',
      (tester) async {
    final data = _ScenarioData.create('block_finalize_unlocked_prizes');
    final state = LiveFixtureState(eventTitle: data.eventTitle);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await _startEventIfNeeded(tester);
      await upsertFixedPrizePlanViaRpc(
        state.eventId!,
        fixedAmounts: const <int>[3000, 2000],
        note: 'Finalize blocker draft plan',
      );

      await pumpUntilVisible(tester, find.text('Complete Event'));
      await tester.tap(find.text('Complete Event'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Finalize Event'));

      await tester.tap(find.text('Finalize Event'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Finalize Event'));

      final eventRow = await Supabase.instance.client
          .from('events')
          .select('lifecycle_status')
          .eq('id', state.eventId!)
          .single();
      expect(eventRow['lifecycle_status'], 'completed');

      final prizePlan = await Supabase.instance.client
          .from('prize_plans')
          .select('status')
          .eq('event_id', state.eventId!)
          .single();
      expect(prizePlan['status'], 'draft');
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_resume_paused_session_when_scoring_closed',
      (tester) async {
    final data = _ScenarioData.create('block_resume_scoring_closed');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(data.normalizedTagUids);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.tableTagUid);
      final sessionId = await startSessionViaUi(
        tester,
        eventId: state.eventId!,
        tableId: tableId,
        tableTagUid: data.tableTagUid,
        playerTagUids: data.playerTagUids,
      );

      await pumpUntilVisible(tester, find.text('Pause Session'));
      await tester.tap(find.text('Pause Session'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Resume Session'));

      await tapBack(tester);
      await tester.pumpAndSettle();
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _closeScoring(tester);
      await openDashboardSection(tester, 'Tables');
      await pumpUntilVisible(tester, find.text('Live Session'));
      await tester.tap(find.text('Live Session').first);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Resume Session'));

      await tester.tap(find.text('Resume Session'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Resume Session'));

      final sessionRow = await Supabase.instance.client
          .from('table_sessions')
          .select('status')
          .eq('id', sessionId)
          .single();
      expect(sessionRow['status'], 'paused');
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_unpaid_guest_cannot_receive_player_tag',
      (tester) async {
    final data = _ScenarioData.create('block_unpaid_guest_tag');
    final state = LiveFixtureState(eventTitle: data.eventTitle);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await _startEventIfNeeded(tester);
      await openDashboardSection(tester, 'Guests');
      await addGuestViaUi(
        tester,
        guestName: data.guestNames.first,
        suffix: data.ids.suffix,
        coverStatus: 'unpaid',
      );
      await pumpUntilVisible(tester, find.text(data.guestNames.first));

      final guestRows = await loadGuestRows(state.eventId!);
      final guestRow = guestRows.firstWhere(
        (row) => row['display_name'] == data.guestNames.first,
      );
      expect(guestRow['cover_status'], 'unpaid');
      final guestId = guestRow['id'] as String;

      final guestNameFinder = find.text(data.guestNames.first).hitTestable();
      await pumpUntilVisible(tester, guestNameFinder);
      await tester.tap(guestNameFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('Check In and Assign Tag'), findsNothing);
      expect(find.text('Assign Tag'), findsNothing);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await checkInGuestViaRpc(guestId);

      await expectLater(
        Supabase.instance.client.rpc(
          'assign_guest_tag',
          params: {
            'target_event_guest_id': guestId,
            'scanned_uid': data.playerTagUids.first,
          },
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
                  'Guest must be paid or comped before receiving a player tag.',
                ),
          ),
        ),
      );

      final assignments = await Supabase.instance.client
          .from('event_guest_tag_assignments')
          .select('id')
          .eq('event_id', state.eventId!);
      expect(assignments, isEmpty);
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_block_guest_without_tag_cannot_start_session',
      (tester) async {
    final data = _ScenarioData.create('block_guest_without_tag');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(
        <String>[
          data.tableTagUid,
          data.playerTagUids[0],
          data.playerTagUids[1],
          data.playerTagUids[2],
          data.untaggedPlayerUid,
        ].map((uid) => uid.toUpperCase()),
      );

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);
      await openDashboardSection(tester, 'Guests');

      final guestRows = await loadGuestRows(state.eventId!);
      final guestIdsByName = {
        for (final row in guestRows)
          row['display_name'] as String: row['id'] as String,
      };

      for (var index = 0; index < 3; index++) {
        await checkInAndAssignTagViaUi(
          tester,
          guestId: guestIdsByName[data.guestNames[index]]!,
          tagUid: data.playerTagUids[index],
        );
      }
      await checkInGuestViaRpc(guestIdsByName[data.guestNames[3]]!);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.tableTagUid);
      await registerPlayerTagViaRpc(
        data.untaggedPlayerUid,
        displayLabel: 'Unassigned blocker tag',
      );

      await expectLater(
        Supabase.instance.client.rpc(
          'start_table_session',
          params: {
            'target_event_table_id': tableId,
            'scanned_table_uid': data.tableTagUid,
            'east_player_uid': data.playerTagUids[0],
            'south_player_uid': data.playerTagUids[1],
            'west_player_uid': data.playerTagUids[2],
            'north_player_uid': data.untaggedPlayerUid,
          },
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
                  'The scanned player tag is not assigned to an eligible guest in this event.',
                ),
          ),
        ),
      );

      final sessions = await Supabase.instance.client
          .from('table_sessions')
          .select('id')
          .eq('event_table_id', tableId);
      expect(sessions, isEmpty);
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets(
      'live_block_guest_already_in_active_session_cannot_start_second_session',
      (tester) async {
    final data = _ScenarioData.create('block_double_booked_guest');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(
        <String>[
          ...data.normalizedTagUids,
          data.secondTableTagUid,
        ],
      );

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final firstTableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.tableTagUid);
      await startSessionViaUi(
        tester,
        eventId: state.eventId!,
        tableId: firstTableId,
        tableTagUid: data.tableTagUid,
        playerTagUids: data.playerTagUids,
      );

      await tapBack(tester);
      await tester.pumpAndSettle();
      final secondTableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.secondTableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.secondTableTagUid);

      await tester.tap(find.text('Start Session').last);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Scan Table Tag'));

      await scanSessionStepViaUi(
          tester, data.secondTableTagUid, 'Scan Table Tag');
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[0],
        'Scan East Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[1],
        'Scan South Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[2],
        'Scan West Player Tag',
      );
      await scanSessionStepViaUi(
        tester,
        data.playerTagUids[3],
        'Scan North Player Tag',
      );

      await pumpUntilVisible(tester, find.text('Review Session'));
      await tester.tap(find.text('Confirm Start Session'));
      await tester.pumpAndSettle();

      final sessions = await Supabase.instance.client
          .from('table_sessions')
          .select('id, event_table_id')
          .eq('event_id', state.eventId!)
          .order('created_at', ascending: true);
      expect(sessions, hasLength(1));
      expect(sessions.single['event_table_id'], firstTableId);
      expect(sessions.single['event_table_id'], isNot(secondTableId));
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_reopen_locked_prize_flow_preserves_awards_and_names',
      (tester) async {
    final data = _ScenarioData.create('reopen_locked_prizes');
    final state = LiveFixtureState(eventTitle: data.eventTitle)
      ..normalizedTagUids.addAll(data.normalizedTagUids);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      await openDashboardSection(tester, 'Guests');
      await _addGuests(tester, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _startEventIfNeeded(tester);

      await openDashboardSection(tester, 'Guests');
      await _checkInAndTagGuests(tester, state.eventId!, data);
      await tapBack(tester);
      await tester.pumpAndSettle();

      await _openScoring(tester);
      await openDashboardSection(tester, 'Tables');
      final tableId = await createTableViaUi(
        tester,
        eventId: state.eventId!,
        tableLabel: data.tableLabel,
      );
      await bindTableTagViaUi(tester, tableTagUid: data.tableTagUid);
      await startSessionViaUi(
        tester,
        eventId: state.eventId!,
        tableId: tableId,
        tableTagUid: data.tableTagUid,
        playerTagUids: data.playerTagUids,
      );

      await recordDiscardHandViaUi(
        tester,
        winnerLabel: '${data.guestNames[0]} (East)',
        discarderLabel: '${data.guestNames[3]} (North)',
        fanCount: '3',
      );

      await tapBack(tester);
      await tester.pumpAndSettle();
      await tapBack(tester);
      await tester.pumpAndSettle();

      await Supabase.instance.client.rpc(
        'upsert_prize_plan',
        params: {
          'target_event_id': state.eventId!,
          'target_mode': 'fixed',
          'target_reserve_fixed_cents': 0,
          'target_reserve_percentage_bps': 0,
          'target_note': 'Locked prize reopen test',
          'target_tiers': [
            {
              'place': 1,
              'label': '1st',
              'fixed_amount_cents': 3000,
            },
            {
              'place': 2,
              'label': '2nd',
              'fixed_amount_cents': 2000,
            },
          ],
        },
      );
      await Supabase.instance.client.rpc(
        'lock_prize_awards',
        params: {'target_event_id': state.eventId!},
      );

      await openDashboardSection(tester, 'Prizes');
      await pumpUntilVisible(tester, find.text('Prize Plan'));
      final lockedAwardsButton =
          find.widgetWithText(OutlinedButton, 'View Locked Awards');
      await tester.scrollUntilVisible(
        lockedAwardsButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(lockedAwardsButton);
      await tester.pumpAndSettle();
      await tester.tap(lockedAwardsButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Prize Awards'));

      expect(find.text(data.guestNames[0]), findsWidgets);
      expect(find.text('Mark Paid'), findsWidgets);

      await tapBack(tester);
      await tester.pumpAndSettle();
      await tapBack(tester);
      await tester.pumpAndSettle();

      await openDashboardSection(tester, 'Prizes');
      await pumpUntilVisible(tester, find.text('Prize Plan'));
      final reopenedLockedAwardsButton =
          find.widgetWithText(OutlinedButton, 'View Locked Awards');
      await tester.scrollUntilVisible(
        reopenedLockedAwardsButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(reopenedLockedAwardsButton);
      await tester.pumpAndSettle();
      await tester.tap(reopenedLockedAwardsButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Prize Awards'));

      expect(find.text(data.guestNames[0]), findsWidgets);
      expect(find.text('Mark Paid'), findsWidgets);
      expect(find.textContaining(data.guestNames[0]), findsWidgets);
    } finally {
      await cleanupLiveFixture(state);
    }
  });

  testWidgets('live_rls_host_can_only_access_own_event_data', (tester) async {
    final data = _ScenarioData.create('rls_host_ownership');
    final state = LiveFixtureState(eventTitle: data.eventTitle);

    await bootAndSignIn(tester);

    try {
      state.eventId = await createEventViaUi(
        tester,
        eventTitle: data.eventTitle,
        venueName: data.venueName,
      );

      final ownerId = Supabase.instance.client.auth.currentUser!.id;
      final forbiddenInsert = Supabase.instance.client.from('events').insert({
        'owner_user_id': '00000000-0000-0000-0000-000000000001',
        'title': '${data.eventTitle} foreign',
        'timezone': 'America/Los_Angeles',
        'starts_at': DateTime.now().toUtc().toIso8601String(),
        'lifecycle_status': 'draft',
        'default_ruleset_id': 'HK_STANDARD_V1',
      });

      await expectLater(forbiddenInsert, throwsA(isA<Object>()));

      final visibleRows = await Supabase.instance.client
          .from('events')
          .select('id, owner_user_id, title')
          .eq('id', state.eventId!);

      expect(visibleRows, hasLength(1));
      expect(visibleRows.single['owner_user_id'], ownerId);

      final foreignRows = await Supabase.instance.client
          .from('events')
          .select('id')
          .neq('owner_user_id', ownerId);
      expect(foreignRows, isEmpty);
    } finally {
      await cleanupLiveFixture(state);
    }
  });
}

class _ScenarioData {
  _ScenarioData({
    required this.ids,
    required this.eventTitle,
    required this.venueName,
    required this.guestNames,
    required this.playerTagUids,
    required this.tableLabel,
    required this.tableTagUid,
    required this.secondTableLabel,
    required this.secondTableTagUid,
    required this.untaggedPlayerUid,
  });

  final LiveRunIds ids;
  final String eventTitle;
  final String venueName;
  final List<String> guestNames;
  final List<String> playerTagUids;
  final String tableLabel;
  final String tableTagUid;
  final String secondTableLabel;
  final String secondTableTagUid;
  final String untaggedPlayerUid;

  List<String> get normalizedTagUids => <String>[...playerTagUids, tableTagUid]
      .map((uid) => uid.toUpperCase())
      .toList();

  static _ScenarioData create(String scenarioName) {
    final ids = LiveRunIds.create(scenarioName);
    final short = ids.suffix.substring(ids.suffix.length - 6);
    return _ScenarioData(
      ids: ids,
      eventTitle: 'Live $short ${ids.scenarioSlug}',
      venueName: 'Simulator Clubhouse',
      guestNames: <String>[
        'East $short',
        'South $short',
        'West $short',
        'North $short',
      ],
      playerTagUids: <String>[
        ids.playerTagUid('east'),
        ids.playerTagUid('south'),
        ids.playerTagUid('west'),
        ids.playerTagUid('north'),
      ],
      tableLabel: 'Table $short',
      tableTagUid: ids.tableTagUid,
      secondTableLabel: 'Table ${short}B',
      secondTableTagUid: '${ids.runPrefix}_TABLE_B'.toUpperCase(),
      untaggedPlayerUid: '${ids.runPrefix}_UNTAGGED'.toUpperCase(),
    );
  }
}

Future<void> _addGuests(WidgetTester tester, _ScenarioData data) async {
  for (var index = 0; index < data.guestNames.length; index++) {
    await addPaidGuestViaUi(
      tester,
      guestName: data.guestNames[index],
      suffix: '${data.ids.suffix}-$index',
    );
    await pumpUntilVisible(tester, find.text(data.guestNames[index]));
  }
}

Future<void> _startEventIfNeeded(WidgetTester tester) async {
  await pumpUntilVisible(tester, find.text('Start Event'));
  await tester.tap(find.text('Start Event'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Check-In Open'));
}

Future<void> _openScoring(WidgetTester tester) async {
  await pumpUntilVisible(tester, find.text('Open Scoring'));
  await tester.tap(find.text('Open Scoring'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scoring Open'));
}

Future<void> _closeScoring(WidgetTester tester) async {
  await pumpUntilVisible(tester, find.text('Close Scoring'));
  await tester.tap(find.text('Close Scoring'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scoring Closed'));
}

Future<void> _checkInAndTagGuests(
  WidgetTester tester,
  String eventId,
  _ScenarioData data,
) async {
  final guestRows = await loadGuestRows(eventId);
  expect(guestRows, hasLength(4));
  for (var index = 0; index < data.guestNames.length; index++) {
    final guestRow = guestRows.firstWhere(
      (row) => row['display_name'] == data.guestNames[index],
    );
    await checkInAndAssignTagViaUi(
      tester,
      guestId: guestRow['id'] as String,
      tagUid: data.playerTagUids[index],
    );
  }
}
