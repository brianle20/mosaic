import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/guests/controllers/bulk_saved_guest_controller.dart';

import '../../../helpers/repository_fakes.dart';

void main() {
  group('BulkSavedGuestController', () {
    test('loads profiles and marks existing profile IDs already added',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
          _profile(id: 'prf_brian', displayName: 'Brian Le'),
        ],
      );
      final controller = _controller(
        repository,
        existingGuests: [
          _guest(id: 'gst_brian', guestProfileId: 'prf_brian'),
        ],
      );

      await controller.loadProfiles();

      expect(repository.listProfileCalls, 1);
      expect(
        controller.profiles.map((profile) => profile.id),
        ['prf_alice', 'prf_brian'],
      );
      expect(controller.isAlreadyAdded('prf_brian'), isTrue);
      expect(controller.isAlreadyAdded('prf_alice'), isFalse);
    });

    test('loadProfiles toggles loading and notifies on success', () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
        ],
        listProfilesGate: Completer<void>(),
      );
      final controller = _controller(repository);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      final load = controller.loadProfiles();

      expect(controller.isLoading, isTrue);
      expect(controller.error, isNull);
      expect(notifications, 1);

      repository.listProfilesGate!.complete();
      await load;

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(
        controller.profiles.map((profile) => profile.id),
        ['prf_alice'],
      );
      expect(notifications, 2);
    });

    test('loadProfiles stores error on failure and clears it before retry',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
        ],
        listProfilesError: StateError('profile load failed'),
      );
      final controller = _controller(repository);

      await controller.loadProfiles();

      expect(controller.isLoading, isFalse);
      expect(controller.error, 'Bad state: profile load failed');
      expect(controller.profiles, isEmpty);

      repository.listProfilesError = null;
      repository.listProfilesGate = Completer<void>();

      final retry = controller.loadProfiles();

      expect(controller.isLoading, isTrue);
      expect(controller.error, isNull);

      repository.listProfilesGate!.complete();
      await retry;

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(
        controller.profiles.map((profile) => profile.id),
        ['prf_alice'],
      );
    });

    test('overlapping loads ignore stale earlier failure after later success',
        () async {
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final repository = _FakeGuestRepository(
        loadPlans: [
          _ProfileLoadPlan(
            gate: firstGate,
            error: StateError('first load failed late'),
          ),
          _ProfileLoadPlan(
            gate: secondGate,
            profiles: [
              _profile(id: 'prf_second', displayName: 'Second Load'),
            ],
          ),
        ],
      );
      final controller = _controller(repository);

      final firstLoad = controller.loadProfiles();
      final secondLoad = controller.loadProfiles();

      expect(controller.isLoading, isTrue);
      expect(controller.error, isNull);

      secondGate.complete();
      await secondLoad;

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(
        controller.profiles.map((profile) => profile.id),
        ['prf_second'],
      );

      firstGate.complete();
      await firstLoad;

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(
        controller.profiles.map((profile) => profile.id),
        ['prf_second'],
      );
    });

    test('loadProfiles does not notify or assign profiles after disposal',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
        ],
        listProfilesGate: Completer<void>(),
      );
      final controller = _controller(repository);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      final load = controller.loadProfiles();
      controller.dispose();
      repository.listProfilesGate!.complete();
      await load;

      expect(controller.profiles, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(notifications, 1);
    });

    test('profiles exposes an immutable profile list', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(id: 'prf_alice', displayName: 'Alice Wong'),
          ],
        ),
      );

      await controller.loadProfiles();

      expect(
        () => controller.profiles.add(
          _profile(id: 'prf_brian', displayName: 'Brian Le'),
        ),
        throwsUnsupportedError,
      );
    });

    test('loadProfiles prunes stale selections to selectable loaded profiles',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_loaded', displayName: 'Loaded Guest'),
          _profile(id: 'prf_already', displayName: 'Already Guest'),
        ],
      );
      final controller = _controller(
        repository,
        existingGuests: [
          _guest(id: 'gst_already', guestProfileId: 'prf_already'),
        ],
      );
      controller.toggleSelection('prf_loaded');
      controller.toggleSelection('prf_missing');

      await controller.loadProfiles();

      expect(controller.selectedProfileIds, unorderedEquals(['prf_loaded']));
    });

    test('search filters by display name case-insensitively', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(id: 'prf_alice', displayName: 'Alice Wong'),
            _profile(id: 'prf_brian', displayName: 'Brian Le'),
          ],
        ),
      );
      await controller.loadProfiles();

      controller.searchQuery = 'wOnG';

      expect(controller.searchQuery, 'wOnG');
      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_alice'],
      );
    });

    test('search filters by public display name when present', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(
              id: 'prf_alice',
              displayName: 'Alice Wong',
              publicDisplayName: 'Mahjong Ace',
            ),
            _profile(id: 'prf_brian', displayName: 'Brian Le'),
          ],
        ),
      );
      await controller.loadProfiles();

      controller.searchQuery = 'ace';

      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_alice'],
      );
    });

    test('search filters by phone, email, and Instagram', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(
              id: 'prf_phone',
              displayName: 'Phone Guest',
              phoneE164: '+14155552671',
            ),
            _profile(
              id: 'prf_email',
              displayName: 'Email Guest',
              emailLower: 'email.match@example.com',
            ),
            _profile(
              id: 'prf_instagram',
              displayName: 'Instagram Guest',
              instagramHandle: 'tile.runner',
            ),
          ],
        ),
      );
      await controller.loadProfiles();

      controller.searchQuery = '5552671';
      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_phone'],
      );

      controller.searchQuery = '(415) 555';
      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_phone'],
      );

      controller.searchQuery = 'MATCH@EXAMPLE';
      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_email'],
      );

      controller.searchQuery = '@TILE.RUN';
      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_instagram'],
      );
    });

    test('search keeps matching already-added profiles visible', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(id: 'prf_already', displayName: 'Already Guest'),
            _profile(id: 'prf_open', displayName: 'Open Guest'),
          ],
        ),
        existingGuests: [
          _guest(id: 'gst_already', guestProfileId: 'prf_already'),
        ],
      );
      await controller.loadProfiles();

      controller.searchQuery = 'already';

      expect(
        controller.filteredProfiles.map((profile) => profile.id),
        ['prf_already'],
      );
      expect(controller.isAlreadyAdded('prf_already'), isTrue);
    });

    test(
        'selecting already-added profile is ignored; selecting/toggling '
        'selectable profile works', () {
      final controller = _controller(
        _FakeGuestRepository(),
        existingGuests: [
          _guest(id: 'gst_already', guestProfileId: 'prf_already'),
        ],
      );

      controller.toggleSelection('prf_already');

      expect(controller.selectedCount, 0);
      expect(controller.isSelected('prf_already'), isFalse);

      controller.toggleSelection('prf_open');

      expect(controller.selectedCount, 1);
      expect(controller.isSelected('prf_open'), isTrue);
      expect(controller.selectedProfileIds, unorderedEquals(['prf_open']));

      controller.toggleSelection('prf_open');

      expect(controller.selectedCount, 0);
      expect(controller.isSelected('prf_open'), isFalse);
      expect(controller.selectedProfileIds, isEmpty);
    });

    test('batch default setters update values and notify listeners', () {
      final controller = _controller(_FakeGuestRepository());
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      expect(controller.tournamentStatus, EventTournamentStatus.qualified);
      expect(controller.coverStatus, CoverStatus.unpaid);
      expect(controller.coverAmountCents, 2500);

      controller.tournamentStatus = EventTournamentStatus.qualifying;
      controller.coverStatus = CoverStatus.comped;
      controller.coverAmountCents = -100;

      expect(controller.tournamentStatus, EventTournamentStatus.qualifying);
      expect(controller.coverStatus, CoverStatus.comped);
      expect(controller.coverAmountCents, 0);
      expect(notifications, 3);
    });

    test('addSelectedGuests creates inputs from profiles and batch defaults',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(
            id: 'prf_alice',
            displayName: 'Alice Wong',
            normalizedName: 'alice wong',
            publicDisplayName: 'Alice W.',
            phoneE164: '+14155552671',
            emailLower: 'alice@example.com',
            instagramHandle: 'alice.wong',
          ),
        ],
      );
      final controller = _controller(repository);
      await controller.loadProfiles();
      controller.tournamentStatus = EventTournamentStatus.qualifying;
      controller.coverStatus = CoverStatus.comped;
      controller.coverAmountCents = 0;
      controller.toggleSelection('prf_alice');

      final result = await controller.addSelectedGuests();

      expect(result.addedCount, 1);
      expect(result.failedCount, 0);
      expect(repository.createInputs, hasLength(1));
      final input = repository.createInputs.single;
      expect(input.eventId, 'evt_01');
      expect(input.guestProfileId, 'prf_alice');
      expect(input.displayName, 'Alice Wong');
      expect(input.normalizedName, 'alice wong');
      expect(input.publicDisplayName, 'Alice W.');
      expect(input.phoneE164, '+14155552671');
      expect(input.emailLower, 'alice@example.com');
      expect(input.instagramHandle, 'alice.wong');
      expect(input.tournamentStatus, EventTournamentStatus.qualifying);
      expect(input.coverStatus, CoverStatus.comped);
      expect(input.coverAmountCents, 0);
      expect(input.isComped, isTrue);
      expect(controller.isSelected('prf_alice'), isFalse);
      expect(controller.isAlreadyAdded('prf_alice'), isTrue);
    });

    test(
        'partial success returns added and failed counts and keeps failed ID '
        'selected', () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_success', displayName: 'Success Guest'),
          _profile(id: 'prf_failure', displayName: 'Failure Guest'),
        ],
        failingProfileIds: {'prf_failure'},
      );
      final controller = _controller(repository);
      await controller.loadProfiles();
      controller.toggleSelection('prf_success');
      controller.toggleSelection('prf_failure');

      final result = await controller.addSelectedGuests();

      expect(result.addedCount, 1);
      expect(result.failedCount, 1);
      expect(controller.isSelected('prf_success'), isFalse);
      expect(controller.isSelected('prf_failure'), isTrue);
      expect(controller.isAlreadyAdded('prf_success'), isTrue);
      expect(controller.isAlreadyAdded('prf_failure'), isFalse);
    });

    test('addSelectedGuests no-ops without selected loaded profiles', () async {
      final controller = _controller(
        _FakeGuestRepository(
          profiles: [
            _profile(id: 'prf_loaded', displayName: 'Loaded Guest'),
          ],
        ),
      );
      await controller.loadProfiles();
      controller.toggleSelection('prf_stale');
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      final result = await controller.addSelectedGuests();

      expect(result.addedCount, 0);
      expect(result.failedCount, 0);
      expect(controller.isSubmitting, isFalse);
      expect(controller.selectedProfileIds, unorderedEquals(['prf_stale']));
      expect(notifications, 0);
    });

    test('addSelectedGuests does not notify or mutate selection after disposal',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
        ],
        createGuestGate: Completer<void>(),
      );
      final controller = _controller(repository);
      await controller.loadProfiles();
      controller.toggleSelection('prf_alice');
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      final add = controller.addSelectedGuests();
      await repository.createGuestStarted!.future;
      controller.dispose();
      repository.createGuestGate!.complete();
      final result = await add;

      expect(result.addedCount, 0);
      expect(result.failedCount, 0);
      expect(controller.isSelected('prf_alice'), isTrue);
      expect(controller.isAlreadyAdded('prf_alice'), isFalse);
      expect(controller.isSubmitting, isFalse);
      expect(notifications, 1);
    });

    test('concurrent addSelectedGuests call no-ops while submit is running',
        () async {
      final repository = _FakeGuestRepository(
        profiles: [
          _profile(id: 'prf_alice', displayName: 'Alice Wong'),
        ],
        createGuestGate: Completer<void>(),
      );
      final controller = _controller(repository);
      await controller.loadProfiles();
      controller.toggleSelection('prf_alice');

      final firstResult = controller.addSelectedGuests();
      await repository.createGuestStarted!.future;

      final secondResult = await controller.addSelectedGuests();

      expect(secondResult.addedCount, 0);
      expect(secondResult.failedCount, 0);
      expect(repository.createInputs, hasLength(1));
      expect(controller.isSubmitting, isTrue);

      repository.createGuestGate!.complete();
      final result = await firstResult;

      expect(result.addedCount, 1);
      expect(result.failedCount, 0);
      expect(controller.isSubmitting, isFalse);
    });

    test('add result exposes UI-friendly status helpers', () {
      const success = BulkSavedGuestAddResult(addedCount: 2, failedCount: 0);
      const partial = BulkSavedGuestAddResult(addedCount: 1, failedCount: 1);
      const failure = BulkSavedGuestAddResult(addedCount: 0, failedCount: 2);
      const noop = BulkSavedGuestAddResult(addedCount: 0, failedCount: 0);

      expect(success.hasFailures, isFalse);
      expect(success.hasPartialSuccess, isFalse);
      expect(success.isCompleteFailure, isFalse);

      expect(partial.hasFailures, isTrue);
      expect(partial.hasPartialSuccess, isTrue);
      expect(partial.isCompleteFailure, isFalse);

      expect(failure.hasFailures, isTrue);
      expect(failure.hasPartialSuccess, isFalse);
      expect(failure.isCompleteFailure, isTrue);

      expect(noop.hasFailures, isFalse);
      expect(noop.hasPartialSuccess, isFalse);
      expect(noop.isCompleteFailure, isFalse);
    });
  });
}

BulkSavedGuestController _controller(
  _FakeGuestRepository repository, {
  List<EventGuestRecord> existingGuests = const [],
}) {
  return BulkSavedGuestController(
    guestRepository: repository,
    eventId: 'evt_01',
    eventCoverChargeCents: 2500,
    existingGuests: existingGuests,
  );
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository({
    List<GuestProfileRecord> profiles = const [],
    Set<String> failingProfileIds = const {},
    List<_ProfileLoadPlan> loadPlans = const [],
    this.listProfilesGate,
    this.listProfilesError,
    this.createGuestGate,
  })  : _profiles = profiles,
        _failingProfileIds = failingProfileIds,
        _loadPlans = List<_ProfileLoadPlan>.from(loadPlans);

  final List<GuestProfileRecord> _profiles;
  final Set<String> _failingProfileIds;
  final List<_ProfileLoadPlan> _loadPlans;
  Completer<void>? listProfilesGate;
  Object? listProfilesError;
  final Completer<void>? createGuestGate;
  Completer<void>? createGuestStarted;
  final createInputs = <CreateGuestInput>[];
  int listProfileCalls = 0;

  @override
  Future<List<GuestProfileRecord>> listGuestProfiles() async {
    listProfileCalls += 1;
    if (_loadPlans.isNotEmpty) {
      final plan = _loadPlans.removeAt(0);
      await plan.gate?.future;
      if (plan.error case final error?) {
        throw error;
      }
      return List<GuestProfileRecord>.from(plan.profiles);
    }

    await listProfilesGate?.future;
    if (listProfilesError case final error?) {
      throw error;
    }
    return List<GuestProfileRecord>.from(_profiles);
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    createGuestStarted ??= Completer<void>();
    createInputs.add(input);
    if (createGuestStarted?.isCompleted == false) {
      createGuestStarted!.complete();
    }
    await createGuestGate?.future;
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
    this.gate,
    this.profiles = const [],
    this.error,
  });

  final Completer<void>? gate;
  final List<GuestProfileRecord> profiles;
  final Object? error;
}

GuestProfileRecord _profile({
  required String id,
  required String displayName,
  String? normalizedName,
  String? publicDisplayName,
  String? phoneE164,
  String? emailLower,
  String? instagramHandle,
}) {
  return GuestProfileRecord(
    id: id,
    ownerUserId: 'host_01',
    displayName: displayName,
    normalizedName: normalizedName ?? displayName.toLowerCase(),
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
