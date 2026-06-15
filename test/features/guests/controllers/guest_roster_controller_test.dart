import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';

void main() {
  test('load shows cached guests while refreshing the roster', () async {
    final alice = _guest(id: 'gst_01', name: 'Alice Wong');
    final repository = _FakeGuestRepository(
      [alice],
      cachedGuests: [alice],
    );
    final controller = GuestRosterController(guestRepository: repository);
    final cachedGuestsLoaded = Completer<void>();
    controller.addListener(() {
      if (controller.guests.isNotEmpty && !cachedGuestsLoaded.isCompleted) {
        cachedGuestsLoaded.complete();
      }
    });

    final load = controller.load('evt_01');
    await cachedGuestsLoaded.future;

    expect(controller.guests.map((guest) => guest.id), ['gst_01']);

    await load;

    expect(controller.guests.map((guest) => guest.id), ['gst_01']);
  });

  test('removeGuest deletes the guest from the loaded roster', () async {
    final alice = _guest(id: 'gst_01', name: 'Alice Wong');
    final bob = _guest(id: 'gst_02', name: 'Bob Lee');
    final repository = _FakeGuestRepository([alice, bob]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('evt_01');
    await controller.removeGuest('gst_01');

    expect(repository.removedGuestIds, ['gst_01']);
    expect(controller.guests.map((guest) => guest.displayName), ['Bob Lee']);
  });

  test('checkInForPlayMode checks in an open-play guest without tags',
      () async {
    final repository = _FakeGuestRepository([
      _guest(id: 'gst_01', name: 'Alice Wong'),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    await controller.checkInForPlayMode(
      guestId: 'gst_01',
      status: EventTournamentStatus.openPlayOnly,
    );

    expect(repository.checkInCalls, 1);
    expect(
      repository.statusUpdates['gst_01'],
      EventTournamentStatus.openPlayOnly,
    );
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.openPlayOnly,
    );
  });

  test('checkInForPlayMode checks in a qualifying guest without tags',
      () async {
    final repository = _FakeGuestRepository([
      _guest(id: 'gst_01', name: 'Alice Wong'),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    await controller.checkInForPlayMode(
      guestId: 'gst_01',
      status: EventTournamentStatus.qualifying,
    );

    expect(repository.checkInCalls, 1);
    expect(
        repository.statusUpdates['gst_01'], EventTournamentStatus.qualifying);
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.qualifying,
    );
  });

  test('checkIn uses the guest current tournament status', () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    await controller.checkIn('gst_01');

    expect(repository.checkInCalls, 1);
    expect(repository.tournamentMutationCalls, 1);
    expect(
        repository.statusUpdates['gst_01'], EventTournamentStatus.qualifying);
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.qualifying,
    );
  });

  test('qualifyCheckedInConsidered promotes only checked-in considered guests',
      () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_checked_considered',
        name: 'Checked Considered',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_expected_considered',
        name: 'Expected Considered',
        attendanceStatus: AttendanceStatus.expected,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_checked_open',
        name: 'Checked Open',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.openPlayOnly,
      ),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    final count = await controller.qualifyCheckedInConsidered();

    expect(count, 1);
    expect(repository.statusUpdates, {
      'gst_checked_considered': EventTournamentStatus.qualified,
    });
  });

  test('qualifyCheckedInConsidered only promotes guests in provided ID set',
      () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_visible',
        name: 'Visible Considered',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_hidden',
        name: 'Hidden Considered',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_pending',
        name: 'Pending Considered',
        attendanceStatus: AttendanceStatus.expected,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    final count = await controller.qualifyCheckedInConsidered(
      guestIds: {'gst_visible', 'gst_pending'},
    );

    expect(count, 1);
    expect(repository.statusUpdates, {
      'gst_visible': EventTournamentStatus.qualified,
    });
  });

  test('qualifyCheckedInConsidered marks promoted guests submitting', () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_checked_considered',
        name: 'Checked Considered',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_expected_considered',
        name: 'Expected Considered',
        attendanceStatus: AttendanceStatus.expected,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ])
      ..tournamentUpdateStarted = Completer<void>()
      ..tournamentUpdateGate = Completer<void>();
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    final future = controller.qualifyCheckedInConsidered();
    await repository.tournamentUpdateStarted!.future;

    expect(controller.isSubmittingGuest('gst_checked_considered'), isTrue);
    expect(controller.isSubmittingGuest('gst_expected_considered'), isFalse);

    repository.tournamentUpdateGate!.complete();
    await future;

    expect(controller.isSubmittingGuest('gst_checked_considered'), isFalse);
  });

  test('qualifyCheckedInConsidered exposes global in-flight state', () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_checked_considered',
        name: 'Checked Considered',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ])
      ..tournamentUpdateStarted = Completer<void>()
      ..tournamentUpdateGate = Completer<void>();
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');

    expect(controller.isQualifyingCheckedInConsidered, isFalse);

    final future = controller.qualifyCheckedInConsidered();
    await repository.tournamentUpdateStarted!.future;

    expect(controller.isQualifyingCheckedInConsidered, isTrue);

    repository.tournamentUpdateGate!.complete();
    await future;

    expect(controller.isQualifyingCheckedInConsidered, isFalse);
  });

  test(
      'qualifyCheckedInConsidered keeps successful updates merged when a later '
      'update fails', () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_first',
        name: 'First',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_fails',
        name: 'Fails',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ])
      ..failingTournamentUpdateIds.add('gst_fails');
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');

    await expectLater(
      controller.qualifyCheckedInConsidered(),
      throwsA(isA<StateError>()),
    );

    expect(
      controller.guests
          .firstWhere((guest) => guest.id == 'gst_first')
          .tournamentStatus,
      EventTournamentStatus.qualified,
    );
    expect(
      controller.guests
          .firstWhere((guest) => guest.id == 'gst_fails')
          .tournamentStatus,
      EventTournamentStatus.qualifying,
    );
  });

  test('qualifyCheckedInConsidered returns 0 while bulk action is in flight',
      () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_first',
        name: 'First',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ])
      ..tournamentUpdateStarted = Completer<void>()
      ..tournamentUpdateGate = Completer<void>();
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    final firstBulk = controller.qualifyCheckedInConsidered();
    await repository.tournamentUpdateStarted!.future;

    final secondCount = await controller.qualifyCheckedInConsidered();

    expect(secondCount, 0);
    expect(repository.tournamentMutationCalls, 1);

    repository.tournamentUpdateGate!.complete();
    expect(await firstBulk, 1);
  });

  test('qualifyCheckedInConsidered skips guests already submitting', () async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_already_submitting',
        name: 'Already Submitting',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_bulk_target',
        name: 'Bulk Target',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
    ])
      ..gatedTournamentUpdateIds.add('gst_already_submitting')
      ..tournamentUpdateStarted = Completer<void>()
      ..tournamentUpdateGate = Completer<void>();
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    final perGuestUpdate = controller.updateTournamentStatus(
      guestId: 'gst_already_submitting',
      status: EventTournamentStatus.qualified,
    );
    await repository.tournamentUpdateStarted!.future;

    final bulkCount = await controller.qualifyCheckedInConsidered();

    expect(bulkCount, 1);
    expect(
      repository.statusUpdates['gst_bulk_target'],
      EventTournamentStatus.qualified,
    );
    expect(controller.isSubmittingGuest('gst_already_submitting'), isTrue);

    repository.tournamentUpdateGate!.complete();
    await perGuestUpdate;
  });
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository(
    this._guests, {
    List<EventGuestRecord> cachedGuests = const [],
  }) : _cachedGuests = List<EventGuestRecord>.from(cachedGuests);

  final List<EventGuestRecord> _guests;
  final List<EventGuestRecord> _cachedGuests;
  final removedGuestIds = <String>[];
  int checkInCalls = 0;
  int tournamentMutationCalls = 0;
  Completer<void>? tournamentUpdateStarted;
  Completer<void>? tournamentUpdateGate;
  final gatedTournamentUpdateIds = <String>{};
  final failingTournamentUpdateIds = <String>{};
  final statusUpdates = <String, EventTournamentStatus>{};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      List<EventGuestRecord>.from(_cachedGuests);

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async =>
      List<EventGuestRecord>.from(_guests);

  @override
  Future<void> removeGuest(String guestId) async {
    removedGuestIds.add(guestId);
    _guests.removeWhere((guest) => guest.id == guestId);
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    checkInCalls += 1;
    final guest = _guests.firstWhere((entry) => entry.id == guestId);
    final updated = EventGuestRecord(
      id: guest.id,
      eventId: guest.eventId,
      guestProfileId: guest.guestProfileId,
      displayName: guest.displayName,
      normalizedName: guest.normalizedName,
      publicDisplayName: guest.publicDisplayName,
      phoneE164: guest.phoneE164,
      emailLower: guest.emailLower,
      instagramHandle: guest.instagramHandle,
      attendanceStatus: AttendanceStatus.checkedIn,
      tournamentStatus: guest.tournamentStatus,
      coverStatus: guest.coverStatus,
      coverAmountCents: guest.coverAmountCents,
      isComped: guest.isComped,
      hasScoredPlay: guest.hasScoredPlay,
      note: guest.note,
      checkedInAt: DateTime.parse('2026-06-04T12:00:00-07:00'),
      rowVersion: guest.rowVersion,
    );
    final index = _guests.indexWhere((entry) => entry.id == guestId);
    _guests[index] = updated;
    return GuestDetailRecord(guest: updated);
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) async {
    throw StateError('recordCoverEntry is not used in these tests');
  }

  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) async {
    tournamentMutationCalls += 1;
    if (tournamentUpdateStarted?.isCompleted == false) {
      tournamentUpdateStarted!.complete();
    }
    if (gatedTournamentUpdateIds.isEmpty ||
        gatedTournamentUpdateIds.contains(eventGuestId)) {
      await tournamentUpdateGate?.future;
    }
    if (failingTournamentUpdateIds.contains(eventGuestId)) {
      throw StateError('Failed to update $eventGuestId');
    }
    statusUpdates[eventGuestId] = status;
    final guest = _guests.firstWhere((entry) => entry.id == eventGuestId);
    final updated = EventGuestRecord(
      id: guest.id,
      eventId: guest.eventId,
      guestProfileId: guest.guestProfileId,
      displayName: guest.displayName,
      normalizedName: guest.normalizedName,
      publicDisplayName: guest.publicDisplayName,
      phoneE164: guest.phoneE164,
      emailLower: guest.emailLower,
      instagramHandle: guest.instagramHandle,
      attendanceStatus: guest.attendanceStatus,
      tournamentStatus: status,
      coverStatus: guest.coverStatus,
      coverAmountCents: guest.coverAmountCents,
      isComped: guest.isComped,
      hasScoredPlay: guest.hasScoredPlay,
      note: guest.note,
      checkedInAt: guest.checkedInAt,
      rowVersion: guest.rowVersion,
    );
    final index = _guests.indexWhere((entry) => entry.id == eventGuestId);
    _guests[index] = updated;
    return updated;
  }
}

EventGuestRecord _guest({
  required String id,
  required String name,
  AttendanceStatus attendanceStatus = AttendanceStatus.expected,
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'event-1',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': switch (attendanceStatus) {
      AttendanceStatus.expected => 'expected',
      AttendanceStatus.checkedIn => 'checked_in',
      AttendanceStatus.checkedOut => 'checked_out',
      AttendanceStatus.noShow => 'no_show',
    },
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
  });
}
