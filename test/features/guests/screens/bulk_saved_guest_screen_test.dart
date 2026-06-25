import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/guests/screens/bulk_saved_guest_screen.dart';

import '../../../helpers/repository_fakes.dart';

void main() {
  testWidgets('renders saved profiles and disables already-added rows', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_ada', displayName: 'Ada Fu'),
        _profile(
          id: 'prf_brian',
          displayName: 'Brian Le',
          publicDisplayName: 'B-Le',
          emailLower: 'brian@example.com',
        ),
      ],
    );

    await _pumpScreen(
      tester,
      repository: repository,
      existingGuests: [
        _guest(id: 'gst_ada', guestProfileId: 'prf_ada'),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Add From Saved Guests'), findsOneWidget);
    expect(find.text('Ada Fu'), findsOneWidget);
    expect(find.text('Already added'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);
    expect(find.text('B-Le'), findsOneWidget);
    expect(find.text('brian@example.com'), findsOneWidget);

    await tester.tap(find.text('Ada Fu'));
    await tester.pump();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Add 0 Guests'), findsOneWidget);
  });

  testWidgets('hides tournament and cover controls without permissions', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
    );

    await _pumpScreen(
      tester,
      repository: repository,
      canManageTournamentStatus: false,
      canManageCover: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tournament Status'), findsNothing);
    expect(find.text('Prequalified'), findsNothing);
    expect(find.byKey(bulkSavedGuestTournamentStatusFieldKey), findsNothing);
    expect(find.text('Cover Status'), findsNothing);
    expect(find.text('Cover Amount'), findsNothing);
    expect(find.byKey(bulkSavedGuestCoverStatusFieldKey), findsNothing);
    expect(find.byKey(bulkSavedGuestCoverAmountFieldKey), findsNothing);
  });

  testWidgets('shows loading while saved profiles are pending', (tester) async {
    final gate = Completer<void>();
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
      listProfilesGate: gate,
    );

    await _pumpScreen(tester, repository: repository);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Brian Le'), findsOneWidget);
  });

  testWidgets('shows load error with retry', (tester) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
      loadPlans: [
        _ProfileLoadPlan(error: StateError('profile load failed')),
        _ProfileLoadPlan(
          profiles: [
            _profile(id: 'prf_brian', displayName: 'Brian Le'),
          ],
        ),
      ],
    );

    await _pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Something needs attention'), findsOneWidget);
    expect(find.text('Bad state: profile load failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Something needs attention'), findsNothing);
    expect(find.text('Brian Le'), findsOneWidget);
    expect(repository.listProfileCalls, 2);
  });

  testWidgets('shows no saved guests empty state', (tester) async {
    final repository = _RecordingGuestRepository(profiles: const []);

    await _pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('No saved guests yet'), findsOneWidget);
    expect(
      find.text(
        'Create guests from the roster first, then they will appear here for future events.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows all-added empty state while keeping disabled rows', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_ada', displayName: 'Ada Fu'),
      ],
    );

    await _pumpScreen(
      tester,
      repository: repository,
      existingGuests: [
        _guest(id: 'gst_ada', guestProfileId: 'prf_ada'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('All saved guests added'), findsOneWidget);
    expect(
      find.text('All saved guests are already on this event.'),
      findsOneWidget,
    );
    expect(find.text('Ada Fu'), findsOneWidget);
    expect(find.text('Already added'), findsOneWidget);
  });

  testWidgets('shows no search results empty state', (tester) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_ada', displayName: 'Ada Fu'),
      ],
    );

    await _pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(bulkSavedGuestSearchFieldKey),
      'zzzz',
    );
    await tester.pump();

    expect(find.text('No matching saved guests'), findsOneWidget);
    expect(find.text('No saved guests match this search.'), findsOneWidget);
    expect(find.text('Ada Fu'), findsNothing);
  });

  testWidgets('searches identity fields and shows checkmark for selection', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_ada', displayName: 'Ada Fu'),
        _profile(
          id: 'prf_nia',
          displayName: 'Nia Stone',
          phoneE164: '+15551234567',
          emailLower: 'needle@example.com',
          instagramHandle: 'nialoop',
        ),
      ],
    );

    await _pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(bulkSavedGuestSearchFieldKey),
      '@nialoop',
    );
    await tester.pump();

    expect(find.text('Nia Stone'), findsOneWidget);
    expect(find.text('Ada Fu'), findsNothing);

    await tester.tap(find.text('Nia Stone'));
    await tester.pump();

    final rowFinder = find.byKey(
      const ValueKey<String>('bulk-saved-guest-row-prf_nia'),
    );
    expect(
      find.descendant(
        of: rowFinder,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Add 1 Guest'), findsOneWidget);
  });

  testWidgets(
    'submits selected guests with considered tournament and changed cover',
    (tester) async {
      final repository = _RecordingGuestRepository(
        profiles: [
          _profile(id: 'prf_brian', displayName: 'Brian Le'),
        ],
      );
      int? poppedResult;

      await _pumpPushableScreen(
        tester,
        repository: repository,
        onPopped: (value) => poppedResult = value,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Brian Le'));
      await tester.pump();

      await tester.tap(find.byKey(bulkSavedGuestTournamentStatusFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Considered').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(bulkSavedGuestCoverStatusFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('paid').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(bulkSavedGuestCoverAmountFieldKey),
        '31.25',
      );
      await tester.pump();

      await tester.tap(find.text('Add 1 Guest'));
      await tester.pumpAndSettle();

      expect(poppedResult, 1);
      expect(repository.createdInputs, hasLength(1));
      expect(repository.createdInputs.single.guestProfileId, 'prf_brian');
      expect(
        repository.createdInputs.single.tournamentStatus,
        EventTournamentStatus.qualifying,
      );
      expect(repository.createdInputs.single.coverStatus, CoverStatus.paid);
      expect(repository.createdInputs.single.coverAmountCents, 3125);
      expect(repository.createdInputs.single.isComped, isFalse);
    },
  );

  testWidgets('shows Prequalified as the default tournament status', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
    );

    await _pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.byKey(bulkSavedGuestTournamentStatusFieldKey), findsOneWidget);
    expect(find.text('Prequalified'), findsOneWidget);
  });

  testWidgets('submits Not Playing tournament status as openPlayOnly', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
    );
    int? poppedResult;

    await _pumpPushableScreen(
      tester,
      repository: repository,
      onPopped: (value) => poppedResult = value,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Brian Le'));
    await tester.pump();

    await tester.tap(find.byKey(bulkSavedGuestTournamentStatusFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Playing').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add 1 Guest'));
    await tester.pumpAndSettle();

    expect(poppedResult, 1);
    expect(
      repository.createdInputs.single.tournamentStatus,
      EventTournamentStatus.openPlayOnly,
    );
  });

  testWidgets('partial failure reports failed guests and stays on screen', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_ada', displayName: 'Ada Fu'),
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
      failingProfileIds: {'prf_brian'},
    );
    int? poppedResult;

    await _pumpPushableScreen(
      tester,
      repository: repository,
      onPopped: (value) => poppedResult = value,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada Fu'));
    await tester.tap(find.text('Brian Le'));
    await tester.pump();

    await tester.tap(find.text('Add 2 Guests'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNull);
    expect(find.text('Add From Saved Guests'), findsOneWidget);
    expect(find.text('Added 1 guest. 1 could not be added.'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Add 1 Guest'), findsOneWidget);
    expect(repository.createdInputs, hasLength(2));
  });

  testWidgets('complete failure stays on screen and shows a snackbar', (
    tester,
  ) async {
    final repository = _RecordingGuestRepository(
      profiles: [
        _profile(id: 'prf_brian', displayName: 'Brian Le'),
      ],
      failingProfileIds: {'prf_brian'},
    );
    int? poppedResult;

    await _pumpPushableScreen(
      tester,
      repository: repository,
      onPopped: (value) => poppedResult = value,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Brian Le'));
    await tester.pump();
    await tester.tap(find.text('Add 1 Guest'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNull);
    expect(find.text('Add From Saved Guests'), findsOneWidget);
    expect(find.text('Could not add selected guests.'), findsOneWidget);
    expect(repository.createdInputs, hasLength(1));
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _RecordingGuestRepository repository,
  List<EventGuestRecord> existingGuests = const [],
  bool canManageTournamentStatus = true,
  bool canManageCover = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BulkSavedGuestScreen(
        eventId: 'evt_01',
        eventCoverChargeCents: 2500,
        existingGuests: existingGuests,
        guestRepository: repository,
        canManageTournamentStatus: canManageTournamentStatus,
        canManageCover: canManageCover,
      ),
    ),
  );
}

Future<void> _pumpPushableScreen(
  WidgetTester tester, {
  required _RecordingGuestRepository repository,
  required ValueChanged<int?> onPopped,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<int>(
                    MaterialPageRoute(
                      builder: (_) => BulkSavedGuestScreen(
                        eventId: 'evt_01',
                        eventCoverChargeCents: 2500,
                        existingGuests: const [],
                        guestRepository: repository,
                      ),
                    ),
                  );
                  onPopped(result);
                },
                child: const Text('Open picker'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

class _RecordingGuestRepository extends ThrowingGuestRepository {
  _RecordingGuestRepository({
    required List<GuestProfileRecord> profiles,
    Set<String> failingProfileIds = const {},
    List<_ProfileLoadPlan> loadPlans = const [],
    this.listProfilesGate,
  })  : _profiles = profiles,
        _failingProfileIds = failingProfileIds,
        _loadPlans = List<_ProfileLoadPlan>.from(loadPlans);

  final List<GuestProfileRecord> _profiles;
  final Set<String> _failingProfileIds;
  final List<_ProfileLoadPlan> _loadPlans;
  Completer<void>? listProfilesGate;
  final createdInputs = <CreateGuestInput>[];
  int listProfileCalls = 0;

  @override
  Future<List<GuestProfileRecord>> listGuestProfiles() async {
    listProfileCalls += 1;
    if (_loadPlans.isNotEmpty) {
      final plan = _loadPlans.removeAt(0);
      if (plan.error case final error?) {
        throw error;
      }
      return List<GuestProfileRecord>.from(plan.profiles);
    }

    await listProfilesGate?.future;
    return List<GuestProfileRecord>.from(_profiles);
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    createdInputs.add(input);
    if (_failingProfileIds.contains(input.guestProfileId)) {
      throw StateError('Failed to add ${input.guestProfileId}');
    }

    return _guest(
      id: 'gst_${input.guestProfileId}',
      guestProfileId: input.guestProfileId ?? 'missing_profile',
      displayName: input.displayName,
      normalizedName: input.normalizedName,
      publicDisplayName: input.publicDisplayName,
      phoneE164: input.phoneE164,
      emailLower: input.emailLower,
      instagramHandle: input.instagramHandle,
      tournamentStatus: input.tournamentStatus,
      coverStatus: input.coverStatus,
      coverAmountCents: input.coverAmountCents,
      isComped: input.isComped,
    );
  }
}

class _ProfileLoadPlan {
  const _ProfileLoadPlan({
    this.profiles = const [],
    this.error,
  });

  final List<GuestProfileRecord> profiles;
  final Object? error;
}

GuestProfileRecord _profile({
  required String id,
  required String displayName,
  String? publicDisplayName,
  String? phoneE164,
  String? emailLower,
  String? instagramHandle,
}) {
  return GuestProfileRecord(
    id: id,
    ownerUserId: 'host_01',
    displayName: displayName,
    normalizedName: displayName.toLowerCase(),
    publicDisplayName: publicDisplayName,
    phoneE164: phoneE164,
    emailLower: emailLower,
    instagramHandle: instagramHandle,
  );
}

EventGuestRecord _guest({
  required String id,
  required String guestProfileId,
  String displayName = 'Existing Guest',
  String normalizedName = 'existing guest',
  String? publicDisplayName,
  String? phoneE164,
  String? emailLower,
  String? instagramHandle,
  EventTournamentStatus tournamentStatus = EventTournamentStatus.qualified,
  CoverStatus coverStatus = CoverStatus.unpaid,
  int coverAmountCents = 0,
  bool isComped = false,
}) {
  return EventGuestRecord(
    id: id,
    eventId: 'evt_01',
    guestProfileId: guestProfileId,
    displayName: displayName,
    normalizedName: normalizedName,
    publicDisplayName: publicDisplayName,
    phoneE164: phoneE164,
    emailLower: emailLower,
    instagramHandle: instagramHandle,
    attendanceStatus: AttendanceStatus.expected,
    tournamentStatus: tournamentStatus,
    coverStatus: coverStatus,
    coverAmountCents: coverAmountCents,
    isComped: isComped,
    hasScoredPlay: false,
  );
}
