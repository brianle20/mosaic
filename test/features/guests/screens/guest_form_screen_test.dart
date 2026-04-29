import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';

class _RecordingGuestRepository implements GuestRepository {
  CreateGuestInput? created;
  List<GuestProfileMatch> matches = const [];
  GuestProfileLookupInput? lastLookupInput;
  int profileLookupCount = 0;

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    created = input;
    return EventGuestRecord.fromJson({
      'id': 'gst_01',
      'event_id': input.eventId,
      'display_name': input.displayName,
      'normalized_name': input.normalizedName,
      'attendance_status': 'expected',
      'cover_status': input.coverStatus.name,
      'cover_amount_cents': input.coverAmountCents,
      'is_comped': input.isComped,
      'has_scored_play': false,
      'phone_e164': input.phoneE164,
      'email_lower': input.emailLower,
      'instagram_handle': input.instagramHandle,
      'note': input.note,
    });
  }

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async {
    profileLookupCount += 1;
    lastLookupInput = input;
    return matches;
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

EventGuestRecord _guestRecord({
  required String id,
  required String name,
  String? guestProfileId,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    if (guestProfileId != null) 'guest_profile_id': guestProfileId,
    'display_name': name,
    'normalized_name': name.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        ),
    'attendance_status': 'expected',
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
  });
}

void main() {
  testWidgets('shows validation and submits a new guest', (tester) async {
    final repository = _RecordingGuestRepository();
    EventGuestRecord? createdGuest;

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (guest) => createdGuest = guest,
        ),
      ),
    );

    await tester.tap(find.text('Save Guest'));
    await tester.pump();
    expect(find.text('Name is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Alice Wong');
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.normalizedName, 'alice wong');
    expect(createdGuest, isNotNull);
  });

  testWidgets('defaults cover amount from the event and formats money input', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          defaultCoverAmountCents: 1500,
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );

    EditableText coverAmountEditable() => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(guestCoverAmountFieldKey),
            matching: find.byType(EditableText),
          ),
        );

    expect(find.text('Cover Amount'), findsOneWidget);
    expect(find.text('Cover Amount (cents)'), findsNothing);
    expect(find.text(r'$'), findsOneWidget);
    expect(coverAmountEditable().controller.text, '15.00');

    await tester.enterText(find.byKey(guestNameFieldKey), 'Alice Wong');
    await tester.tap(find.byKey(guestCoverAmountFieldKey));
    await tester.pump();
    tester.testTextInput.enterText('5');
    await tester.pump();
    expect(coverAmountEditable().controller.text, '0.05');

    tester.testTextInput.enterText('${coverAmountEditable().controller.text}0');
    await tester.pump();
    expect(coverAmountEditable().controller.text, '0.50');

    tester.testTextInput.enterText('${coverAmountEditable().controller.text}0');
    await tester.pump();
    expect(coverAmountEditable().controller.text, '5.00');

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.coverAmountCents, 500);
  });

  testWidgets('shows an existing guest profile match and stores phone as E.164',
      (tester) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.phone,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_01',
            'owner_user_id': 'usr_01',
            'display_name': 'Brian Le',
            'normalized_name': 'brian le',
            'phone_e164': '+14155552671',
          }),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(guestNameFieldKey), 'Brian Le');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '4155552671');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Using existing guest: Brian Le'), findsOneWidget);
    expect(repository.lastLookupInput?.phoneE164, '+14155552671');

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.phoneE164, '+14155552671');
  });

  testWidgets('debounces profile matching without showing loading text', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.phone,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_01',
            'owner_user_id': 'usr_01',
            'display_name': 'Brian Le',
            'normalized_name': 'brian le',
            'phone_e164': '+14155552671',
          }),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '4155552671',
    );
    await tester.pump();

    expect(find.text('Checking saved guests...'), findsNothing);
    expect(find.text('Using existing guest: Brian Le'), findsNothing);
    expect(repository.profileLookupCount, 0);

    await tester.pump(const Duration(milliseconds: 399));

    expect(repository.profileLookupCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.profileLookupCount, 1);
    expect(find.text('Checking saved guests...'), findsNothing);
    expect(find.text('Using existing guest: Brian Le'), findsOneWidget);
  });

  testWidgets('stores Instagram handles and uses them for profile matching', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.instagram,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_01',
            'owner_user_id': 'usr_01',
            'display_name': 'Brian Le',
            'normalized_name': 'brian le',
            'instagram_handle': 'brian.le',
          }),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(guestNameFieldKey), 'Brian Le');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram'),
      '@Brian.Le',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.lastLookupInput?.instagramHandle, 'brian.le');
    expect(find.text('Using existing guest: Brian Le'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.instagramHandle, 'brian.le');
  });

  testWidgets('blocks invalid Instagram handles', (tester) async {
    final repository = _RecordingGuestRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(guestNameFieldKey), 'Brian Le');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram'),
      '@brian-le',
    );
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pump();

    expect(
      find.text(
        'Use letters, numbers, periods, or underscores, up to 30 characters.',
      ),
      findsOneWidget,
    );
    expect(repository.created, isNull);
  });

  testWidgets('hides the edited guest profile from possible matches', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.name,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_01',
            'owner_user_id': 'usr_01',
            'display_name': 'Brian Le',
            'normalized_name': 'brian le',
          }),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          initialGuest: _guestRecord(
            id: 'gst_01',
            guestProfileId: 'prf_01',
            name: 'Brian Le',
          ),
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Possible match: Brian Le'), findsNothing);
    expect(find.text('Using existing guest: Brian Le'), findsNothing);
  });

  testWidgets('renders note as a compact field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: _RecordingGuestRepository(),
          onSaved: (_) {},
        ),
      ),
    );

    final noteEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Note'),
        matching: find.byType(EditableText),
      ),
    );

    expect(noteEditable.maxLines, 1);
  });

  testWidgets('confirms before saving a duplicate guest name', (tester) async {
    final repository = _RecordingGuestRepository();
    EventGuestRecord? createdGuest;

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: [
            _guestRecord(id: 'gst_existing', name: 'Alice Wong'),
          ],
          guestRepository: repository,
          onSaved: (guest) => createdGuest = guest,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Alice Wong');
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Add duplicate guest?'), findsOneWidget);
    expect(
      find.text(
        'Alice Wong is already on this event. Add another guest with the same name?',
      ),
      findsOneWidget,
    );
    expect(repository.created, isNull);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Add duplicate guest?'), findsNothing);
    expect(repository.created, isNull);
    expect(createdGuest, isNull);

    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Anyway'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.normalizedName, 'alice wong');
    expect(createdGuest, isNotNull);
  });
}
