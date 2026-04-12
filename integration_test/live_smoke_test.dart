import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/main.dart' as app;
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hostEmail = String.fromEnvironment('HOST_EMAIL');
const _hostPassword = String.fromEnvironment('HOST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'host can sign in, score hands, configure prizes, and verify payout tracking',
      (tester) async {
    if (_hostEmail.isEmpty || _hostPassword.isEmpty) {
      fail(
        'HOST_EMAIL and HOST_PASSWORD dart defines are required for the live smoke test.',
      );
    }

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
    Map<String, String> guestNamesById = const {};

    app.main();
    await tester.pump();

    await _pumpUntilAny(
      tester,
      [
        find.text('Host Sign In'),
        find.text('Events'),
        find.textContaining('SUPABASE_'),
      ],
    );

    if (find.text('Sign out').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await _pumpUntilVisible(tester, find.text('Host Sign In'));
    }

    expect(find.text('Host Sign In'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), _hostEmail);
    await tester.enterText(find.byType(TextFormField).at(1), _hostPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    await _pumpUntilVisible(
      tester,
      find.widgetWithText(FilledButton, 'Create Event'),
    );

    try {
      await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
      await tester.pump();
      await _pumpUntilVisible(tester, find.text('Create Event'));

      await tester.enterText(find.byType(TextFormField).at(0), eventTitle);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Venue Name'),
        venueName,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cover Charge (cents)'),
        '2000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Prize Budget (cents)'),
        '5000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Event'));
      await tester.pump();

      await _pumpUntilVisible(tester, find.text(eventTitle));
      await _pumpUntilVisible(tester, find.text('Guests: 0'));

      final eventRow = await Supabase.instance.client
          .from('events')
          .select('id, title')
          .eq('title', eventTitle)
          .maybeSingle();

      expect(eventRow, isNotNull);
      eventId = eventRow!['id'] as String;

      await tester.tap(find.text('Guests'));
      await tester.pump();
      await _pumpUntilVisible(tester, find.text('No guests yet.'));

      for (var index = 0; index < guestNames.length; index++) {
        await _addPaidGuest(
          tester,
          guestName: guestNames[index],
          suffix: '$suffix-$index',
        );
        await _pumpUntilVisible(tester, find.text(guestNames[index]));
      }

      final guestRows = await Supabase.instance.client
          .from('event_guests')
          .select('id, display_name, attendance_status')
          .eq('event_id', eventId)
          .order('display_name', ascending: true);
      expect(guestRows, hasLength(4));
      guestNamesById = {
        for (final guest in guestRows)
          guest['id'] as String: guest['display_name'] as String,
      };

      for (var index = 0; index < guestNames.length; index++) {
        final guestRow = guestRows.firstWhere(
          (row) => row['display_name'] == guestNames[index],
        );
        final guestId = guestRow['id'] as String;

        final guestRowFinder =
            find.byKey(ValueKey('guest-row-$guestId')).hitTestable();
        await _pumpUntilVisible(tester, guestRowFinder);
        await tester.ensureVisible(guestRowFinder);
        await tester.tap(guestRowFinder);
        await tester.pumpAndSettle();
        await _pumpUntilVisible(tester, find.text('Check In and Assign Tag'));

        await tester.tap(find.text('Check In and Assign Tag'));
        await tester.pumpAndSettle();
        await _pumpUntilVisible(tester, find.text('Enter Tag UID'));

        final assignmentTagField = find.byType(TextField).hitTestable();
        await _pumpUntilVisible(tester, assignmentTagField);
        await tester.enterText(assignmentTagField, playerTagUids[index]);
        await tester.tap(find.text('Use Tag'));
        await tester.pumpAndSettle();

        await _pumpUntilVisible(tester, find.text('Replace Tag'));
        await _pumpUntilVisible(tester, find.text('Tag Assigned'));
        await _tapBack(tester);
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

      await _tapBack(tester);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Tables'));

      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Add Table'));

      await tester.tap(find.text('Add Table'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Add Table'));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Label'),
        tableLabel,
      );
      await tester.tap(find.text('Save Table'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text(tableLabel));

      final tableRows = await Supabase.instance.client
          .from('event_tables')
          .select('id, label, nfc_tag_id')
          .eq('event_id', eventId)
          .eq('label', tableLabel);
      expect(tableRows, isNotEmpty);
      tableId = tableRows.first['id'] as String;

      await tester.tap(find.text('Bind Table Tag').first);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Edit Table'));

      await tester.tap(find.text('Bind Table Tag'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Scan Table Tag'));
      final tableTagField = find.byType(TextField).hitTestable();
      await _pumpUntilVisible(tester, tableTagField);
      await tester.enterText(tableTagField, tableTagUid);
      await tester.tap(find.text('Use Tag'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Table Tag Bound'));

      await _tapBack(tester);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Table Tag Bound'));

      await tester.tap(find.text('Start Session').first);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Scan Table Tag'));

      await _scanSessionStep(tester, tableTagUid, 'Scan Table Tag');
      await _scanSessionStep(tester, playerTagUids[0], 'Scan East Player Tag');
      await _scanSessionStep(
        tester,
        playerTagUids[1],
        'Scan South Player Tag',
      );
      await _scanSessionStep(tester, playerTagUids[2], 'Scan West Player Tag');
      await _scanSessionStep(
        tester,
        playerTagUids[3],
        'Scan North Player Tag',
      );

      await _pumpUntilVisible(tester, find.text('Review Session'));
      for (final guestName in guestNames) {
        await _pumpUntilVisible(tester, find.text(guestName));
      }

      await tester.tap(find.text('Confirm Start Session'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Session Detail'));

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

      await _recordDiscardHand(
        tester,
        winnerLabel: '${guestNames[2]} (West)',
        discarderLabel: '${guestNames[0]} (East)',
        fanCount: '2',
      );
      await _recordSelfDrawHand(
        tester,
        winnerLabel: '${guestNames[1]} (South)',
        fanCount: '1',
      );
      await _recordWashoutHand(tester);

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
      expect(leaderboardBeforeVoid.first['total_points'], 20);
      expect(leaderboardBeforeVoid[1]['display_name'], guestNames[2]);
      expect(leaderboardBeforeVoid[1]['total_points'], 16);

      await _pumpUntilVisible(tester, find.text('Hand 2'));
      await tester.tap(find.text('Hand 2'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Void Hand'));
      await tester.tap(find.text('Void Hand'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Session Detail'));

      final leaderboardAfterVoid = await Supabase.instance.client.rpc(
        'get_event_leaderboard',
        params: {'target_event_id': eventId},
      ) as List<dynamic>;
      expect(leaderboardAfterVoid.first['display_name'], guestNames[2]);
      expect(leaderboardAfterVoid.first['total_points'], 24);
      final tiedEntries = leaderboardAfterVoid
          .where((entry) => entry['total_points'] == -4)
          .map((entry) => entry['display_name'] as String)
          .toSet();
      expect(tiedEntries, containsAll(<String>[guestNames[1], guestNames[3]]));

      await _tapBack(tester);
      await tester.pumpAndSettle();
      await _tapBack(tester);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Leaderboard'));

      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text(guestNames[2]));
      await _pumpUntilVisible(tester, find.text('24 pts'));

      await _tapBack(tester);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Prizes'));

      await tester.tap(find.text('Prizes'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Prize Plan'));

      await Supabase.instance.client.rpc(
        'upsert_prize_plan',
        params: {
          'target_event_id': eventId,
          'target_mode': 'fixed',
          'target_reserve_fixed_cents': 0,
          'target_reserve_percentage_bps': 0,
          'target_note': 'Smoke test payout',
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
      final prizePlanContext = tester.element(find.byType(PrizePlanScreen));
      Navigator.of(prizePlanContext).pushNamed(
        AppRouter.prizeAwardsRoute,
        arguments: PrizeAwardsArgs(
          eventId: eventId,
          guestNamesById: guestNamesById,
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Prize Awards'));
      await _pumpUntilVisible(tester, find.text(guestNames[2]));

      await tester.tap(find.text('Mark Paid').first);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('paid'));

      final prizeAwards = await Supabase.instance.client
          .from('prize_awards')
          .select('display_rank, award_amount_cents, status')
          .eq('event_id', eventId)
          .order('rank_start', ascending: true);
      expect(prizeAwards, hasLength(1));
      expect(prizeAwards.first['award_amount_cents'], 5000);
      expect(prizeAwards.first['status'], 'paid');

      // Event activation is still a separate product slice, so the live smoke
      // promotes the event to active before verifying completion/finalization
      // against the real backend RPCs.
      await Supabase.instance.client
          .from('events')
          .update({'lifecycle_status': 'active', 'scoring_open': true}).eq(
              'id', eventId);
      await Supabase.instance.client
          .from('table_sessions')
          .update({
            'status': 'ended_early',
            'ended_at': DateTime.now().toIso8601String(),
            'ended_by_user_id': Supabase.instance.client.auth.currentUser!.id,
            'end_reason': 'smoke test finalization',
          })
          .eq('event_id', eventId)
          .inFilter('status', ['active', 'paused']);

      await Supabase.instance.client.rpc(
        'complete_event',
        params: {'target_event_id': eventId},
      );
      await Supabase.instance.client.rpc(
        'finalize_event',
        params: {'target_event_id': eventId},
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

Future<void> _addPaidGuest(
  WidgetTester tester, {
  required String guestName,
  required String suffix,
}) async {
  final addGuestButton =
      find.widgetWithText(FilledButton, 'Add Guest').hitTestable();
  await _pumpUntilVisible(tester, addGuestButton);
  await tester.ensureVisible(addGuestButton);
  await tester.tap(addGuestButton);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Add Guest'));

  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), guestName);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone'),
    '+1415555${suffix.replaceAll('-', '').padLeft(5, '0').substring(0, 5)}',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'smoke+$suffix@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Cover Amount (cents)'),
    '2000',
  );
  await tester.tap(find.text('unpaid').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('paid').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Note'),
    'Live smoke test guest',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Save Guest'));
  await tester.pumpAndSettle();
}

Future<void> _scanSessionStep(
  WidgetTester tester,
  String uid,
  String prompt,
) async {
  await _pumpUntilVisible(tester, find.text(prompt));
  await tester.tap(find.text('Scan Next Tag'));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text(prompt));
  final tagField = find.byType(TextField).hitTestable();
  await _pumpUntilVisible(tester, tagField);
  await tester.enterText(tagField, uid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();
}

Future<void> _recordDiscardHand(
  WidgetTester tester, {
  required String winnerLabel,
  required String discarderLabel,
  required String fanCount,
}) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await _pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Self Draw'));

  await tester.tap(find.text('Discard').hitTestable());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Winner'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(winnerLabel).last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Discarder'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(discarderLabel).last);
  await tester.pumpAndSettle();

  await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'), fanCount);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Session Detail'));
  await _pumpUntilVisible(tester, recordHandButton);
}

Future<void> _recordSelfDrawHand(
  WidgetTester tester, {
  required String winnerLabel,
  required String fanCount,
}) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await _pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Self Draw'));

  await tester.tap(find.text('Winner'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(winnerLabel).last);
  await tester.pumpAndSettle();

  await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'), fanCount);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Session Detail'));
  await _pumpUntilVisible(tester, recordHandButton);
}

Future<void> _recordWashoutHand(WidgetTester tester) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await _pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Washout'));

  await tester.tap(find.text('Washout'));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.text('Session Detail'));
  await _pumpUntilVisible(tester, recordHandButton);
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for ${finder.describeMatch(Plurality.many)}');
}

Future<void> _pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
  }

  fail(
    'Timed out waiting for any of: ${finders.map((finder) => finder.describeMatch(Plurality.many)).join(', ')}',
  );
}

Future<void> _tapBack(WidgetTester tester) async {
  final backButton = find.byTooltip('Back').hitTestable().first;
  await _pumpUntilVisible(tester, backButton);
  await tester.tap(backButton);
}
