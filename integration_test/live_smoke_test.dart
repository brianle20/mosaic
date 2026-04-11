import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mosaic/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

const _hostEmail = String.fromEnvironment('HOST_EMAIL');
const _hostPassword = String.fromEnvironment('HOST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'host can sign in, create an event, add a guest, and assign a player tag',
      (tester) async {
    if (_hostEmail.isEmpty || _hostPassword.isEmpty) {
      fail(
        'HOST_EMAIL and HOST_PASSWORD dart defines are required for the live smoke test.',
      );
    }

    final suffix = DateTime.now().millisecondsSinceEpoch;
    final eventTitle = 'Smoke Event $suffix';
    final guestName = 'Smoke Guest $suffix';
    final venueName = 'Simulator Clubhouse';
    final tagUid = 'SMOKE$suffix';
    final normalizedTagUid = tagUid.toUpperCase();

    String? eventId;
    String? guestId;

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

      await tester.tap(find.widgetWithText(FilledButton, 'Add Guest'));
      await tester.pump();
      await _pumpUntilVisible(tester, find.text('Add Guest'));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), guestName);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        '+14155550123',
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
      await tester.pump();

      await _pumpUntilVisible(tester, find.text(guestName));

      final guestRows = await Supabase.instance.client
          .from('event_guests')
          .select('id, display_name, attendance_status')
          .eq('event_id', eventId)
          .eq('display_name', guestName);

      expect(guestRows, isNotEmpty);
      guestId = guestRows.first['id'] as String;

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

      await tester.enterText(find.byType(TextField), tagUid);
      await tester.tap(find.text('Use Tag'));
      await tester.pumpAndSettle();

      await _pumpUntilVisible(tester, find.text('Replace Tag'));
      await _pumpUntilVisible(tester, find.text('Tag Assigned'));

      final updatedGuest = await Supabase.instance.client
          .from('event_guests')
          .select('id, attendance_status')
          .eq('id', guestId)
          .maybeSingle();
      expect(updatedGuest, isNotNull);
      expect(updatedGuest!['attendance_status'], 'checked_in');

      final assignmentRows = await Supabase.instance.client
          .from('event_guest_tag_assignments')
          .select('id, status, nfc_tag_id')
          .eq('event_id', eventId)
          .eq('event_guest_id', guestId)
          .eq('status', 'assigned');
      expect(assignmentRows, isNotEmpty);

      final tagRows = await Supabase.instance.client
          .from('nfc_tags')
          .select('id, uid_hex')
          .eq('uid_hex', normalizedTagUid);
      expect(tagRows, isNotEmpty);
    } finally {
      if (eventId != null) {
        await Supabase.instance.client
            .from('event_guest_tag_assignments')
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
        await Supabase.instance.client
            .from('event_guests')
            .delete()
            .eq('display_name', guestName);
        await Supabase.instance.client
            .from('events')
            .delete()
            .eq('title', eventTitle);
      }

      await Supabase.instance.client
          .from('nfc_tags')
          .delete()
          .eq('uid_hex', normalizedTagUid);
    }
  });
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
