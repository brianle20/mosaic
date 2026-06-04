import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

void main() {
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

  test('identifyGuestByTag returns found result and caches assignment',
      () async {
    final repository = _FakeGuestRepository([])
      ..tagLookupResult = GuestTagLookupResult(
        guest: _guest(id: 'guest-1', name: 'Caren Ly'),
        assignment: _assignment(eventGuestId: 'guest-1'),
      );
    final controller = GuestRosterController(guestRepository: repository);

    final result = await controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () async => const TagScanResult(
        rawUid: '0a0b0c',
        normalizedUid: '0A0B0C',
        isManualEntry: false,
      ),
    );

    expect(result.status, GuestTagIdentificationStatus.found);
    expect(result.lookup!.guest.displayName, 'Caren Ly');
    expect(controller.guests.single.id, 'guest-1');
    expect(controller.activeTagAssignments['guest-1']!.tag.uidHex, '0A0B0C');
    expect(repository.lookupCalls, 1);
  });

  test('identifyGuestByTag returns notFound for an unassigned tag', () async {
    final repository = _FakeGuestRepository([]);
    final controller = GuestRosterController(guestRepository: repository);

    final result = await controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () async => const TagScanResult(
        rawUid: 'missing',
        normalizedUid: 'MISSING',
        isManualEntry: false,
      ),
    );

    expect(result.status, GuestTagIdentificationStatus.notFound);
    expect(result.scannedUid, 'MISSING');
    expect(controller.guests, isEmpty);
    expect(repository.lookupCalls, 1);
  });

  test('identifyGuestByTag returns cancelled when scan is cancelled', () async {
    final repository = _FakeGuestRepository([]);
    final controller = GuestRosterController(guestRepository: repository);

    final result = await controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () async => null,
    );

    expect(result.status, GuestTagIdentificationStatus.cancelled);
    expect(repository.lookupCalls, 0);
  });

  test('identifyGuestByTag returns cancelled while already identifying',
      () async {
    final repository = _FakeGuestRepository([]);
    final controller = GuestRosterController(guestRepository: repository);
    final scanCompleter = Completer<TagScanResult?>();

    final firstScan = controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () => scanCompleter.future,
    );

    expect(controller.isIdentifyingTag, isTrue);

    final secondScan = await controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () async => const TagScanResult(
        rawUid: '0a0b0c',
        normalizedUid: '0A0B0C',
        isManualEntry: false,
      ),
    );

    expect(secondScan.status, GuestTagIdentificationStatus.cancelled);
    expect(repository.lookupCalls, 0);

    scanCompleter.complete(null);
    await firstScan;

    expect(controller.isIdentifyingTag, isFalse);
  });

  test('identifyGuestByTag does not mutate guest state outside lookup',
      () async {
    final repository = _FakeGuestRepository([])
      ..tagLookupResult = GuestTagLookupResult(
        guest: _guest(id: 'guest-1', name: 'Caren Ly'),
        assignment: _assignment(eventGuestId: 'guest-1'),
      );
    final controller = GuestRosterController(guestRepository: repository);

    await controller.identifyGuestByTag(
      eventId: 'event-1',
      scanForTag: () async => const TagScanResult(
        rawUid: '0a0b0c',
        normalizedUid: '0A0B0C',
        isManualEntry: false,
      ),
    );

    expect(repository.checkInCalls, 0);
    expect(repository.assignTagCalls, 0);
    expect(repository.coverCalls, 0);
    expect(repository.tournamentMutationCalls, 0);
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
    expect(repository.assignTagCalls, 0);
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
    expect(repository.assignTagCalls, 0);
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
    expect(repository.assignTagCalls, 0);
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.qualifying,
    );
  });
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository(this._guests);

  final List<EventGuestRecord> _guests;
  final removedGuestIds = <String>[];
  GuestTagLookupResult? tagLookupResult;
  int lookupCalls = 0;
  int checkInCalls = 0;
  int assignTagCalls = 0;
  int coverCalls = 0;
  int tournamentMutationCalls = 0;
  final statusUpdates = <String, EventTournamentStatus>{};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async =>
      List<EventGuestRecord>.from(_guests);

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<GuestTagLookupResult?> resolveGuestByActiveTag({
    required String eventId,
    required String scannedUid,
  }) async {
    lookupCalls += 1;
    return tagLookupResult;
  }

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
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    assignTagCalls += 1;
    throw StateError('identifyGuestByTag must not assign tags');
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) async {
    coverCalls += 1;
    throw StateError('identifyGuestByTag must not record cover');
  }

  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) async {
    tournamentMutationCalls += 1;
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
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'event-1',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': 'expected',
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
  });
}

GuestTagAssignmentSummary _assignment({required String eventGuestId}) {
  return GuestTagAssignmentSummary.fromJson({
    'assignment_id': 'assignment-1',
    'event_id': 'event-1',
    'event_guest_id': eventGuestId,
    'status': 'assigned',
    'assigned_at': '2026-05-30T00:00:00Z',
    'nfc_tag': {
      'id': 'tag-1',
      'uid_hex': '0A0B0C',
      'uid_fingerprint': 'fingerprint-1',
      'default_tag_type': 'player',
      'status': 'active',
      'display_label': 'UID 1F',
    },
  });
}
