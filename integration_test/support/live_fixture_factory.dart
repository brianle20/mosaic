import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_backend_assertions.dart';
import 'live_test_harness.dart';

Future<String> createEventViaUi(
  WidgetTester tester, {
  required String eventTitle,
  required String venueName,
  String coverChargeCents = '2000',
}) async {
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
    coverChargeCents,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Save Event'));
  await tester.pump();

  await pumpUntilVisible(tester, find.text(eventTitle));
  await pumpUntilVisible(tester, find.text('Guests'));
  return lookupEventIdByTitle(eventTitle);
}

Future<void> openDashboardSection(
  WidgetTester tester,
  String label,
) async {
  final sectionFinders = label == 'Prizes'
      ? [
          find.text('Prizes'),
          find.text('Prize Pool'),
        ]
      : label == 'Leaderboard'
          ? [
              find.text('Leaderboard'),
              find.text('Leader'),
            ]
          : [find.text(label)];
  await pumpUntilAny(tester, sectionFinders);
  final sectionFinder = sectionFinders.firstWhere(
    (finder) => finder.evaluate().isNotEmpty,
  );
  await tester.ensureVisible(sectionFinder.first);
  await tester.tap(sectionFinder.first);
  await tester.pumpAndSettle();
}

Future<void> recordCoverEntryViaUi(
  WidgetTester tester, {
  required String amountCents,
  required String methodLabel,
  required String note,
}) async {
  await pumpUntilVisible(tester, find.text('Cover Ledger'));
  await tester.tap(find.text('Add Cover Entry'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Record Cover Entry'));
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Amount'),
    amountCents,
  );
  await tester.tap(find.widgetWithText(OutlinedButton, methodLabel));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Note'),
    note,
  );
  await tester.tap(find.text('Save Cover Entry'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text(note));
}

Future<void> checkInAndAssignTagViaUi(
  WidgetTester tester, {
  required String guestId,
  required String tagUid,
}) async {
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
  await tester.enterText(assignmentTagField, tagUid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();

  await pumpUntilVisible(tester, find.text('Replace Tag'));
  await pumpUntilVisible(tester, find.text('Tag Assigned'));
  await tapBack(tester);
  await tester.pumpAndSettle();
}

Future<String> createTableViaUi(
  WidgetTester tester, {
  required String eventId,
  required String tableLabel,
  required String tableTagUid,
}) async {
  final normalizedTableTagUid =
      tableTagUid.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '').toUpperCase();
  await pumpUntilVisible(tester, find.text('Add Table'));
  await tester.tap(find.text('Add Table'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Add Table'));

  await pumpUntilVisible(tester, find.text('Scan Table Tag'));
  await tester.tap(find.text('Scan Table Tag'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scan Table Tag'));
  final tableTagField = find.byType(TextField).hitTestable();
  await pumpUntilVisible(tester, tableTagField);
  await tester.enterText(tableTagField, tableTagUid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();

  await pumpUntilAny(tester, [
    find.text(tableLabel),
    find.text('Ready'),
  ]);

  final tagRows = await Supabase.instance.client
      .from('nfc_tags')
      .select('id')
      .eq('uid_hex', normalizedTableTagUid);
  expect(tagRows, isNotEmpty);

  final tableRows = await Supabase.instance.client
      .from('event_tables')
      .select('id')
      .eq('event_id', eventId)
      .eq('nfc_tag_id', tagRows.first['id'] as String);
  expect(tableRows, isNotEmpty);
  return tableRows.first['id'] as String;
}

Future<void> bindTableTagViaUi(
  WidgetTester tester, {
  required String tableTagUid,
}) async {
  final overviewBindAction = find.text('Bind Tag').hitTestable();
  await pumpUntilVisible(tester, overviewBindAction);
  await tester.tap(overviewBindAction.first);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Edit Table'));

  await tester.tap(find.text('Bind Table Tag'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scan Table Tag'));
  final tableTagField = find.byType(TextField).hitTestable();
  await pumpUntilVisible(tester, tableTagField);
  await tester.enterText(tableTagField, tableTagUid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Table Tag Bound'));

  await tapBack(tester);
  await tester.pumpAndSettle();
  await pumpUntilAny(tester, [
    find.text('Ready'),
    find.text('Tag Bound'),
  ]);
}

Future<String> startSessionViaUi(
  WidgetTester tester, {
  required String eventId,
  required String tableId,
  required String tableTagUid,
  required List<String> playerTagUids,
}) async {
  await tapBack(tester);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scan Table'));
  final scanTableAction = find.byIcon(Icons.nfc).hitTestable();
  await pumpUntilVisible(tester, scanTableAction);
  await tester.tap(scanTableAction.first);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scan Table Tag'));
  final tableTagField = find.byType(TextField).hitTestable();
  await pumpUntilVisible(tester, tableTagField);
  await tester.enterText(tableTagField, tableTagUid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Start Session'));

  await scanSessionStepViaUi(tester, playerTagUids[0], 'Scan East Player Tag');
  await scanSessionStepViaUi(tester, playerTagUids[1], 'Scan South Player Tag');
  await scanSessionStepViaUi(tester, playerTagUids[2], 'Scan West Player Tag');
  await scanSessionStepViaUi(tester, playerTagUids[3], 'Scan North Player Tag');

  await pumpUntilVisible(tester, find.text('Review Session'));
  await tester.tap(find.text('Confirm Start Session'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Session Progress'));

  return lookupSessionId(eventId, tableId);
}

Future<void> addPaidGuestViaUi(
  WidgetTester tester, {
  required String guestName,
  required String suffix,
}) async {
  await addGuestViaUi(
    tester,
    guestName: guestName,
    suffix: suffix,
    coverStatus: 'paid',
  );
}

Future<void> addGuestViaUi(
  WidgetTester tester, {
  required String guestName,
  required String suffix,
  String coverStatus = 'paid',
  String coverAmountCents = '2000',
}) async {
  final phoneDigits = suffix.replaceAll(RegExp(r'\D'), '');
  final paddedPhoneDigits = phoneDigits.padLeft(7, '0');
  final phoneNumber =
      '415${paddedPhoneDigits.substring(paddedPhoneDigits.length - 7)}';
  final addGuestButton = find.byIcon(Icons.person_add).hitTestable();
  await pumpUntilVisible(tester, addGuestButton);
  await tester.ensureVisible(addGuestButton.first);
  await tester.tap(addGuestButton.first);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.widgetWithText(TextFormField, 'Name'));

  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), guestName);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone'),
    phoneNumber,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'smoke+$suffix@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Cover Amount'),
    coverAmountCents,
  );
  if (coverStatus != 'unpaid') {
    await tester.tap(
      find
          .byWidgetPredicate((widget) => widget is DropdownButtonFormField)
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(coverStatus).last);
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Note'),
    'Live smoke test guest',
  );
  final saveGuestButton =
      find.widgetWithText(FilledButton, 'Save Guest').hitTestable();
  await pumpUntilVisible(tester, saveGuestButton);
  await tester.ensureVisible(saveGuestButton.first);
  await tester.tap(saveGuestButton.first);
  await tester.pump();
  await pumpUntilAbsent(tester, find.widgetWithText(TextFormField, 'Name'));
  await pumpUntilVisible(tester, find.text(guestName));
}

Future<void> checkInGuestViaRpc(String guestId) async {
  await Supabase.instance.client.rpc(
    'check_in_guest',
    params: {'target_event_guest_id': guestId},
  );
}

Future<void> registerPlayerTagViaRpc(
  String tagUid, {
  String? displayLabel,
}) async {
  await Supabase.instance.client.rpc(
    'register_nfc_tag',
    params: {
      'scanned_uid': tagUid,
      'requested_tag_type': 'player',
      'scanned_display_label': displayLabel,
    },
  );
}

Future<void> upsertFixedPrizePlanViaRpc(
  String eventId, {
  required List<int> fixedAmounts,
  String note = 'Live blocker test prize plan',
}) async {
  await Supabase.instance.client.rpc(
    'upsert_prize_plan',
    params: {
      'target_event_id': eventId,
      'target_mode': 'fixed',
      'target_reserve_fixed_cents': 0,
      'target_reserve_percentage_bps': 0,
      'target_note': note,
      'target_tiers': [
        for (var index = 0; index < fixedAmounts.length; index++)
          {
            'place': index + 1,
            'label': '${index + 1}${switch (index) {
              0 => 'st',
              1 => 'nd',
              2 => 'rd',
              _ => 'th',
            }}',
            'fixed_amount_cents': fixedAmounts[index],
          },
      ],
    },
  );
}

Future<void> scanSessionStepViaUi(
  WidgetTester tester,
  String uid,
  String prompt,
) async {
  await pumpUntilVisible(tester, find.text(prompt));
  await tester.tap(find.text('Scan Next Tag'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text(prompt));
  final tagField = find.byType(TextField).hitTestable();
  await pumpUntilVisible(tester, tagField);
  await tester.enterText(tagField, uid);
  await tester.tap(find.text('Use Tag'));
  await tester.pumpAndSettle();
}

Future<void> endSessionEarlyViaUi(WidgetTester tester, String reason) async {
  await pumpUntilVisible(tester, find.text('End'));
  await tester.tap(find.text('End'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('End Session Early'));
  await tester.enterText(find.byType(TextFormField).last, reason);
  await tester.tap(find.text('End Session'));
  await tester.pumpAndSettle();
}

Future<void> recordDiscardHandViaUi(
  WidgetTester tester, {
  required String winnerLabel,
  required String discarderLabel,
  required String fanCount,
}) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Self Draw'));

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
    find.widgetWithText(TextFormField, 'Fan Count'),
    fanCount,
  );
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Session Progress'));
  await pumpUntilVisible(tester, recordHandButton);
}

Future<void> recordSelfDrawHandViaUi(
  WidgetTester tester, {
  required String winnerLabel,
  required String fanCount,
}) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Self Draw'));

  await tester.tap(find.text('Winner'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(winnerLabel).last);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Fan Count'),
    fanCount,
  );
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Session Progress'));
  await pumpUntilVisible(tester, recordHandButton);
}

Future<void> recordWashoutHandViaUi(WidgetTester tester) async {
  final recordHandButton =
      find.widgetWithText(FilledButton, 'Record Hand').hitTestable();
  await pumpUntilVisible(tester, recordHandButton);
  await tester.tap(recordHandButton);
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Washout'));

  await tester.tap(find.text('Washout'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Scoring Preview'));

  await tester.tap(find.text('Save Hand'));
  await tester.pumpAndSettle();
  await pumpUntilVisible(tester, find.text('Session Progress'));
  await pumpUntilVisible(tester, recordHandButton);
}
