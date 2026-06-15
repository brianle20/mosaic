import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';

class _RecordingGuestRepository extends ThrowingGuestRepository {
  CreateGuestInput? created;
  UpdateGuestInput? updated;
  List<GuestProfileMatch> matches = const [];
  GuestProfileLookupInput? lastLookupInput;
  int profileLookupCount = 0;

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

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
      'guest_profile_id': input.guestProfileId,
      'phone_e164': input.phoneE164,
      'email_lower': input.emailLower,
      'instagram_handle': input.instagramHandle,
      'tournament_status': eventTournamentStatusToJson(
        input.tournamentStatus,
      ),
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
    required DateTime transactionOn,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) async {
    updated = input;
    return EventGuestRecord.fromJson({
      'id': input.id,
      'event_id': input.eventId,
      'display_name': input.displayName,
      'normalized_name': input.normalizedName,
      'attendance_status': 'expected',
      'cover_status': input.coverStatus.name,
      'cover_amount_cents': input.coverAmountCents,
      'is_comped': input.isComped,
      'has_scored_play': false,
      'guest_profile_id': 'prf_01',
      'phone_e164': input.phoneE164,
      'email_lower': input.emailLower,
      'instagram_handle': input.instagramHandle,
      'tournament_status': eventTournamentStatusToJson(
        input.tournamentStatus ?? EventTournamentStatus.openPlayOnly,
      ),
      'note': input.note,
      'public_display_name': input.publicDisplayName,
    });
  }
}

EventGuestRecord _guestRecord({
  required String id,
  required String name,
  String? guestProfileId,
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
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
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
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

  testWidgets('shows public display name directly below full name', (
    tester,
  ) async {
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

    expect(find.byKey(guestNameFieldKey), findsOneWidget);
    expect(find.byKey(guestPublicDisplayNameFieldKey), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Public Display Name'), findsOneWidget);

    final nameTop = tester.getTopLeft(find.byKey(guestNameFieldKey)).dy;
    final publicNameTop =
        tester.getTopLeft(find.byKey(guestPublicDisplayNameFieldKey)).dy;
    expect(nameTop, lessThan(publicNameTop));
  });

  testWidgets('saves generated and manually overridden public display names', (
    tester,
  ) async {
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
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created?.displayName, 'Brian Le');
    expect(repository.created?.publicDisplayName, 'Brian L.');

    repository.created = null;
    await tester.enterText(
      find.byKey(guestPublicDisplayNameFieldKey),
      'Brian from Table 1',
    );
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created?.publicDisplayName, 'Brian from Table 1');
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

  testWidgets(
    'new guest defaults to prequalified tournament qualification',
    (tester) async {
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

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Tournament Qualification'), findsOneWidget);
      expect(find.text('Prequalified'), findsOneWidget);
      expect(find.text('Considered'), findsOneWidget);
      expect(find.text('Not Playing Tournament'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(guestNameFieldKey), 'Alice Wong');
      await tester.ensureVisible(find.text('Save Guest'));
      await tester.tap(find.text('Save Guest'));
      await tester.pumpAndSettle();

      expect(repository.created?.tournamentStatus,
          EventTournamentStatus.qualified);
      expect(createdGuest?.tournamentStatus, EventTournamentStatus.qualified);
    },
  );

  testWidgets('tournament qualification selector fills narrow screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);

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

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    final fieldBox = tester.renderObject<RenderBox>(
      find.byKey(guestTournamentQualificationFieldKey),
    );
    final selectorBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('guest-tournament-qualification-selector')),
    );

    expect(selectorBox.size.width, greaterThanOrEqualTo(fieldBox.size.width));
  });

  testWidgets('selecting considered saves qualifying tournament status', (
    tester,
  ) async {
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

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Considered'));
    await tester.tap(find.text('Considered'));
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(guestNameFieldKey), 'Alice Wong');
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(
        repository.created?.tournamentStatus, EventTournamentStatus.qualifying);
    expect(createdGuest?.tournamentStatus, EventTournamentStatus.qualifying);
  });

  testWidgets('editing an open play guest preserves tournament status on save',
      (
    tester,
  ) async {
    final repository = _RecordingGuestRepository();
    EventGuestRecord? updatedGuest;

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          initialGuest: _guestRecord(
            id: 'gst_01',
            name: 'Alice Wong',
            tournamentStatus: EventTournamentStatus.openPlayOnly,
          ),
          guestRepository: repository,
          onSaved: (guest) => updatedGuest = guest,
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Tournament Qualification'), findsOneWidget);
    expect(find.text('Not Playing Tournament'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.updated?.tournamentStatus,
        EventTournamentStatus.openPlayOnly);
    expect(updatedGuest?.tournamentStatus, EventTournamentStatus.openPlayOnly);
  });

  testWidgets('editing a withdrawn guest shows and preserves withdrawn status',
      (
    tester,
  ) async {
    final repository = _RecordingGuestRepository();
    EventGuestRecord? updatedGuest;

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          initialGuest: _guestRecord(
            id: 'gst_01',
            name: 'Alice Wong',
            tournamentStatus: EventTournamentStatus.withdrawn,
          ),
          guestRepository: repository,
          onSaved: (guest) => updatedGuest = guest,
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Tournament Qualification'), findsOneWidget);
    expect(find.text('Withdrawn'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(
        repository.updated?.tournamentStatus, EventTournamentStatus.withdrawn);
    expect(updatedGuest?.tournamentStatus, EventTournamentStatus.withdrawn);
  });

  testWidgets('requires an explicit action before using a phone profile match',
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
            'public_display_name': 'BL',
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

    expect(find.text('Brian Le exists from another event.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Use Existing Guest'),
        findsOneWidget);
    expect(find.text('Using existing guest: Brian Le'), findsNothing);
    expect(repository.lastLookupInput?.phoneE164, '+14155552671');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Use Existing Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Using existing guest: Brian Le'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(guestPublicDisplayNameFieldKey),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'BL',
    );

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.phoneE164, '+14155552671');
    expect(repository.created!.publicDisplayName, 'BL');
  });

  testWidgets('requires an explicit action before using an email profile match',
      (tester) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.email,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_01',
            'owner_user_id': 'usr_01',
            'display_name': 'Ada Fu',
            'normalized_name': 'ada fu',
            'email_lower': 'ada@example.com',
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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'Ada@Example.com',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.lastLookupInput?.emailLower, 'ada@example.com');
    expect(find.text('Ada Fu exists from another event.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Use Existing Guest'),
        findsOneWidget);
    expect(find.text('Using existing guest: Ada Fu'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Use Existing Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Using existing guest: Ada Fu'), findsOneWidget);
  });

  testWidgets('requires an explicit action before using a name-only profile', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository()
      ..matches = [
        GuestProfileMatch(
          matchType: GuestProfileMatchType.name,
          profile: GuestProfileRecord.fromJson(const {
            'id': 'prf_estevon',
            'owner_user_id': 'usr_01',
            'display_name': 'Estevon Jackson',
            'normalized_name': 'estevon jackson',
            'phone_e164': '+14087582753',
            'instagram_handle': 'estevon',
          }),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_03',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(guestNameFieldKey), 'Estevon Jackson');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Possible match: Estevon Jackson'), findsNothing);
    expect(find.text('Estevon Jackson exists from another event.'),
        findsOneWidget);
    expect(
      find.text(
          'Use this guest profile to keep their info synced across events.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Use Existing Guest'),
        findsOneWidget);
    expect(find.text('Using existing guest: Estevon Jackson'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Use Existing Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Using existing guest: Estevon Jackson'), findsOneWidget);
    expect(
        find.text('Estevon Jackson exists from another event.'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Phone'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created?.guestProfileId, 'prf_estevon');
    expect(repository.created?.phoneE164, '+14087582753');
    expect(repository.created?.instagramHandle, 'estevon');
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
    expect(find.text('Brian Le exists from another event.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Use Existing Guest'),
        findsOneWidget);
    expect(find.text('Using existing guest: Brian Le'), findsNothing);
  });

  testWidgets('requires an explicit action before using an Instagram match', (
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
    expect(find.text('Brian Le exists from another event.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Use Existing Guest'),
        findsOneWidget);
    expect(find.text('Using existing guest: Brian Le'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Use Existing Guest'));
    await tester.pumpAndSettle();

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

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

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
