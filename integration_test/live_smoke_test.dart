import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/live_fixture_factory.dart';
import 'support/live_test_harness.dart';

void main() {
  ensureIntegrationTestBinding();

  testWidgets('live_golden_full_event_lifecycle', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final eventTitle = 'Smoke Event $suffix';
    final venueName = 'Simulator Clubhouse';
    final guestNames = [
      'Smoke East $suffix',
      'Smoke South $suffix',
      'Smoke West $suffix',
      'Smoke North $suffix',
    ];
    final playerTagUids = [
      'SMOKEE$suffix',
      'SMOKES$suffix',
      'SMOKEW$suffix',
      'SMOKEN$suffix',
    ];
    final normalizedPlayerTagUids =
        playerTagUids.map((uid) => uid.toUpperCase()).toList(growable: false);
    final tableLabel = 'Table $suffix';
    final tableTagUid = 'SMOKET$suffix';
    final normalizedTableTagUid = tableTagUid.toUpperCase();

    String? eventId;
    String? tableId;

    await bootAndSignIn(tester);

    try {
      await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
      await tester.pump();
      await pumpUntilVisible(tester, find.text('Create Event'));

      await tester.enterText(find.byType(TextFormField).at(0), eventTitle);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Venue Name'),
        venueName,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cover Charge'),
        '2000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Event'));
      await tester.pump();

      await pumpUntilVisible(tester, find.text(eventTitle));
      await pumpUntilVisible(tester, find.text('Guests'));

      final eventRow = await Supabase.instance.client
          .from('events')
          .select('id, title')
          .eq('title', eventTitle)
          .maybeSingle();

      expect(eventRow, isNotNull);
      eventId = eventRow!['id'] as String;

      await tester.tap(find.text('Guests'));
      await tester.pump();
      await pumpUntilVisible(tester, find.text('No guests yet'));
      await pumpUntilVisible(
        tester,
        find.text(
          'Add guests to start check-in, tag assignment, and live seating.',
        ),
      );

      for (var index = 0; index < guestNames.length; index++) {
        await addPaidGuestViaUi(
          tester,
          guestName: guestNames[index],
          suffix: '$suffix-$index',
        );
        await pumpUntilVisible(tester, find.text(guestNames[index]));
      }

      final guestRows = await Supabase.instance.client
          .from('event_guests')
          .select('id, display_name, attendance_status')
          .eq('event_id', eventId)
          .order('display_name', ascending: true);
      expect(guestRows, hasLength(4));

      final firstGuestId = guestRows.first['id'] as String;
      final firstGuestName = guestRows.first['display_name'] as String;
      final firstGuestFinder =
          find.byKey(ValueKey('guest-row-$firstGuestId')).hitTestable();
      await pumpUntilVisible(tester, firstGuestFinder);
      await tester.tap(firstGuestFinder);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Cover Ledger'));
      await tester.tap(find.text('Add Cover Entry'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Record Cover Entry'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '2000',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cash'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note'),
        'Paid at door via smoke test',
      );
      await tester.tap(find.text('Save Cover Entry'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Paid at door via smoke test'));
      await pumpUntilVisible(tester, find.text(firstGuestName));

      final coverEntryRows = await Supabase.instance.client
          .from('guest_cover_entries')
          .select('event_guest_id, amount_cents, method, note')
          .eq('event_id', eventId)
          .order('transaction_on', ascending: false)
          .order('created_at', ascending: false);
      expect(coverEntryRows, hasLength(1));
      expect(coverEntryRows.first['event_guest_id'], firstGuestId);
      expect(coverEntryRows.first['amount_cents'], 2000);
      expect(coverEntryRows.first['method'], 'cash');
      expect(coverEntryRows.first['note'], 'Paid at door via smoke test');

      await tapBack(tester);
      await tester.pumpAndSettle();

      await tapBack(tester);
      await tester.pumpAndSettle();
      await pumpUntilAny(tester, [
        find.text('Open Check-In'),
        find.text('Start Event'),
      ]);

      final startAction = find.text('Open Check-In').evaluate().isNotEmpty
          ? find.text('Open Check-In')
          : find.text('Start Event');
      await tester.tap(startAction);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Check-In Open'));
      await pumpUntilAny(tester, [
        find.text('Scoring Not Open'),
        find.text('Scoring Closed'),
      ]);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(
          tester, find.text('Recorded cover entry: cash 2000'));
      await pumpUntilVisible(tester, find.text('Started event'));

      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(
          tester, find.text('Recorded cover entry: cash 2000'));
      expect(find.text('Started event'), findsNothing);

      await tapBack(tester);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Guests'));

      await tester.tap(find.text('Guests'));
      await tester.pumpAndSettle();

      for (var index = 0; index < guestNames.length; index++) {
        final guestRow = guestRows.firstWhere(
          (row) => row['display_name'] == guestNames[index],
        );
        final guestId = guestRow['id'] as String;

        final guestRowFinder =
            find.byKey(ValueKey('guest-row-$guestId')).hitTestable();
        await pumpUntilVisible(tester, guestRowFinder);
        await tester.ensureVisible(guestRowFinder);
        await tester.tap(guestRowFinder);
        await tester.pumpAndSettle();
        await pumpUntilVisible(tester, find.text('Check In and Assign Tag'));

        await tester.tap(find.text('Check In and Assign Tag'));
        await tester.pumpAndSettle();
        await pumpUntilVisible(tester, find.text('Enter Tag UID'));

        final assignmentTagField = find.byType(TextField).hitTestable();
        await pumpUntilVisible(tester, assignmentTagField);
        await tester.enterText(assignmentTagField, playerTagUids[index]);
        await tester.tap(find.text('Use Tag'));
        await tester.pumpAndSettle();

        await pumpUntilVisible(tester, find.text('Replace Tag'));
        await pumpUntilVisible(tester, find.text('Tag Assigned'));
        await tapBack(tester);
        await tester.pumpAndSettle();
      }

      final updatedGuests = await Supabase.instance.client
          .from('event_guests')
          .select('id, attendance_status')
          .eq('event_id', eventId);
      expect(
        updatedGuests.every(
          (guest) => guest['attendance_status'] == 'checked_in',
        ),
        isTrue,
      );

      await tapBack(tester);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Check-In Open'));
      await pumpUntilAny(tester, [
        find.text('Scoring Not Open'),
        find.text('Scoring Closed'),
      ]);
      await pumpUntilVisible(tester, find.text('Open Scoring'));

      await tester.tap(find.text('Open Scoring'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Scoring Open'));

      await openDashboardSection(tester, 'Tables');
      tableId = await createTableViaUi(
        tester,
        eventId: eventId,
        tableLabel: tableLabel,
        tableTagUid: tableTagUid,
      );
      await startSessionViaUi(
        tester,
        eventId: eventId,
        tableId: tableId,
        tableTagUid: tableTagUid,
        playerTagUids: playerTagUids,
      );
      await pumpUntilVisible(tester, find.text('Session Progress'));
      await pumpUntilVisible(tester, find.text('Pause'));

      final sessionRows = await Supabase.instance.client
          .from('table_sessions')
          .select('id, event_table_id, status')
          .eq('event_id', eventId)
          .eq('event_table_id', tableId);
      expect(sessionRows, hasLength(1));
      expect(sessionRows.single['status'], 'active');

      final sessionId = sessionRows.single['id'] as String;
      final seatRows = await Supabase.instance.client
          .from('table_session_seats')
          .select('seat_index, initial_wind, event_guest_id')
          .eq('table_session_id', sessionId)
          .order('seat_index', ascending: true);
      expect(seatRows, hasLength(4));
      expect(
        seatRows.map((seat) => seat['initial_wind']).toList(),
        ['east', 'south', 'west', 'north'],
      );

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Resume'));

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Record Hand'),
      );

      await recordDiscardHandViaUi(
        tester,
        winnerLabel: '${guestNames[2]} (West)',
        discarderLabel: '${guestNames[0]} (East)',
        fanCount: '3',
      );
      await recordSelfDrawHandViaUi(
        tester,
        winnerLabel: '${guestNames[1]} (South)',
        fanCount: '3',
      );
      await recordWashoutHandViaUi(tester);

      final recordedHands = await Supabase.instance.client
          .from('hand_results')
          .select('id, hand_number, result_type, status')
          .eq('table_session_id', sessionId)
          .order('hand_number', ascending: true);
      expect(recordedHands, hasLength(3));

      final leaderboardBeforeVoid = await Supabase.instance.client.rpc(
        'get_event_leaderboard',
        params: {'target_event_id': eventId},
      ) as List<dynamic>;
      expect(leaderboardBeforeVoid.first['display_name'], guestNames[1]);
      expect(leaderboardBeforeVoid.first['total_points'], 48);
      expect(leaderboardBeforeVoid[1]['display_name'], guestNames[2]);
      expect(leaderboardBeforeVoid[1]['total_points'], 16);

      await pumpUntilVisible(tester, find.text('Hand 2'));
      await tester.scrollUntilVisible(
        find.text('Hand 2'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      final handTwoFinder = find.text('Hand 2').hitTestable();
      await pumpUntilVisible(tester, handTwoFinder);
      await tester.tap(handTwoFinder.first);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Void Hand'));
      await tester.tap(find.text('Void Hand'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Session Progress'));

      final leaderboardAfterVoid = await Supabase.instance.client.rpc(
        'get_event_leaderboard',
        params: {'target_event_id': eventId},
      ) as List<dynamic>;
      expect(leaderboardAfterVoid.first['display_name'], guestNames[2]);
      expect(leaderboardAfterVoid.first['total_points'], 32);
      final voidedHands = await Supabase.instance.client
          .from('hand_results')
          .select('status')
          .eq('table_session_id', sessionId)
          .eq('hand_number', 2);
      expect(voidedHands.single['status'], 'voided');

      await endSessionEarlyViaUi(tester, 'Smoke test wrap-up');
      await pumpUntilVisible(
        tester,
        find.text('Ended early: Smoke test wrap-up'),
      );

      await tapBack(tester);
      await tester.pumpAndSettle();

      await openDashboardSection(tester, 'Leaderboard');
      await pumpUntilVisible(tester, find.text(guestNames[2]));
      await pumpUntilVisible(tester, find.text('32 pts'));

      await tapBack(tester);
      await tester.pumpAndSettle();

      await openDashboardSection(tester, 'Prizes');
      await pumpUntilVisible(tester, find.text('Prize Plan'));

      await Supabase.instance.client.rpc(
        'upsert_prize_plan',
        params: {
          'target_event_id': eventId,
          'target_mode': 'fixed',
          'target_reserve_fixed_cents': 0,
          'target_reserve_percentage_bps': 0,
          'target_note': 'Smoke test locked awards',
          'target_tiers': [
            {
              'place': 1,
              'label': '1st',
              'fixed_amount_cents': 5000,
            },
          ],
        },
      );
      await Supabase.instance.client.rpc(
        'lock_prize_awards',
        params: {'target_event_id': eventId},
      );
      final prizeAwards = await Supabase.instance.client
          .from('prize_awards')
          .select('id, display_rank, award_amount_cents')
          .eq('event_id', eventId)
          .order('rank_start', ascending: true);
      expect(prizeAwards, hasLength(1));
      expect(prizeAwards.first['display_rank'], '1st');
      expect(prizeAwards.first['award_amount_cents'], 5000);

      await tapBack(tester);
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Complete Event'));

      await tester.tap(find.text('Complete Event'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Finalize Event'));

      await tester.tap(find.text('Finalize Event'));
      await tester.pumpAndSettle();
      await pumpUntilVisible(tester, find.text('Results Locked'));
      await pumpUntilVisible(
        tester,
        find.text('Standings and awards are locked for this event.'),
      );

      final finalizedEventRow = await Supabase.instance.client
          .from('events')
          .select('lifecycle_status, checkin_open, scoring_open')
          .eq('id', eventId)
          .single();
      expect(finalizedEventRow['lifecycle_status'], 'finalized');
      expect(finalizedEventRow['checkin_open'], isFalse);
      expect(finalizedEventRow['scoring_open'], isFalse);
    } finally {
      if (eventId != null) {
        await Supabase.instance.client
            .from('guest_cover_entries')
            .delete()
            .eq('event_id', eventId);
      }
      if (eventId != null) {
        await Supabase.instance.client
            .from('prize_awards')
            .delete()
            .eq('event_id', eventId);
      }
      if (eventId != null) {
        await Supabase.instance.client
            .from('event_guest_tag_assignments')
            .delete()
            .eq('event_id', eventId);
      }
      if (eventId != null) {
        await Supabase.instance.client
            .from('table_sessions')
            .delete()
            .eq('event_id', eventId);
        await Supabase.instance.client
            .from('event_tables')
            .delete()
            .eq('event_id', eventId);
      }
      if (eventId != null) {
        await Supabase.instance.client
            .from('event_guests')
            .delete()
            .eq('event_id', eventId);
        await Supabase.instance.client
            .from('events')
            .delete()
            .eq('id', eventId);
      } else {
        for (final guestName in guestNames) {
          await Supabase.instance.client
              .from('event_guests')
              .delete()
              .eq('display_name', guestName);
        }
        await Supabase.instance.client
            .from('events')
            .delete()
            .eq('title', eventTitle);
      }

      for (final uid in [...normalizedPlayerTagUids, normalizedTableTagUid]) {
        await Supabase.instance.client
            .from('nfc_tags')
            .delete()
            .eq('uid_hex', uid);
      }
    }
  });
}
