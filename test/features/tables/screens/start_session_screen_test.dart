import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/start_session_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository({
    required this.guests,
    required this.assignments,
  });

  final List<EventGuestRecord> guests;
  final Map<String, GuestTagAssignmentSummary> assignments;

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
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      assignments;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

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

class _FakeSessionRepository implements SessionRepository {
  StartTableSessionInput? startedInput;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(
      StartTableSessionInput input) async {
    startedInput = input;
    return StartedTableSessionRecord.fromJson(
      sessionJson: const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD_V1',
        'ruleset_version': 1,
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'active',
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': 0,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 0,
        'started_at': '2026-04-24T19:00:00-07:00',
        'started_by_user_id': 'usr_01',
      },
      seatsJson: const [
        {
          'id': 'seat_01',
          'table_session_id': 'ses_01',
          'seat_index': 0,
          'initial_wind': 'east',
          'event_guest_id': 'gst_east',
        },
        {
          'id': 'seat_02',
          'table_session_id': 'ses_01',
          'seat_index': 1,
          'initial_wind': 'south',
          'event_guest_id': 'gst_south',
        },
        {
          'id': 'seat_03',
          'table_session_id': 'ses_01',
          'seat_index': 2,
          'initial_wind': 'west',
          'event_guest_id': 'gst_west',
        },
        {
          'id': 'seat_04',
          'table_session_id': 'ses_01',
          'seat_index': 3,
          'initial_wind': 'north',
          'event_guest_id': 'gst_north',
        },
      ],
    );
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _QueuedNfcService implements NfcService {
  _QueuedNfcService(this.results);

  final List<TagScanResult?> results;

  TagScanResult? _takeNext() => results.removeAt(0);

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
          BuildContext context) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async =>
      _takeNext();

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async =>
      _takeNext();
}

void main() {
  Map<String, GuestTagAssignmentSummary> buildAssignments() {
    return const {
      'gst_east': {
        'assignment_id': 'asg_east',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_east',
        'status': 'assigned',
        'assigned_at': '2026-04-24T18:00:00-07:00',
        'nfc_tag': {
          'id': 'tag_east',
          'uid_hex': 'PLAYER-EAST',
          'uid_fingerprint': 'PLAYER-EAST',
          'default_tag_type': 'player',
          'status': 'active',
        },
      },
      'gst_south': {
        'assignment_id': 'asg_south',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_south',
        'status': 'assigned',
        'assigned_at': '2026-04-24T18:01:00-07:00',
        'nfc_tag': {
          'id': 'tag_south',
          'uid_hex': 'PLAYER-SOUTH',
          'uid_fingerprint': 'PLAYER-SOUTH',
          'default_tag_type': 'player',
          'status': 'active',
        },
      },
      'gst_west': {
        'assignment_id': 'asg_west',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_west',
        'status': 'assigned',
        'assigned_at': '2026-04-24T18:02:00-07:00',
        'nfc_tag': {
          'id': 'tag_west',
          'uid_hex': 'PLAYER-WEST',
          'uid_fingerprint': 'PLAYER-WEST',
          'default_tag_type': 'player',
          'status': 'active',
        },
      },
      'gst_north': {
        'assignment_id': 'asg_north',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_north',
        'status': 'assigned',
        'assigned_at': '2026-04-24T18:03:00-07:00',
        'nfc_tag': {
          'id': 'tag_north',
          'uid_hex': 'PLAYER-NORTH',
          'uid_fingerprint': 'PLAYER-NORTH',
          'default_tag_type': 'player',
          'status': 'active',
        },
      },
    }.map(
      (guestId, json) => MapEntry(
        guestId,
        GuestTagAssignmentSummary.fromJson(json),
      ),
    );
  }

  List<EventGuestRecord> buildGuests() {
    return const [
      {
        'id': 'gst_east',
        'event_id': 'evt_01',
        'display_name': 'Alice Wong',
        'normalized_name': 'alice wong',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      },
      {
        'id': 'gst_south',
        'event_id': 'evt_01',
        'display_name': 'Bob Lee',
        'normalized_name': 'bob lee',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      },
      {
        'id': 'gst_west',
        'event_id': 'evt_01',
        'display_name': 'Carol Ng',
        'normalized_name': 'carol ng',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      },
      {
        'id': 'gst_north',
        'event_id': 'evt_01',
        'display_name': 'Dee Wu',
        'normalized_name': 'dee wu',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      },
    ].map(EventGuestRecord.fromJson).toList(growable: false);
  }

  testWidgets('walks table then east south west north into review and confirm',
      (tester) async {
    final sessionRepository = _FakeSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StartSessionScreen(
          eventId: 'evt_01',
          table: EventTableRecord.fromJson(const {
            'id': 'tbl_01',
            'event_id': 'evt_01',
            'label': 'Table 1',
            'mode': 'points',
            'display_order': 1,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'default_rotation_policy_type':
                'dealer_cycle_return_to_initial_east',
            'default_rotation_policy_config_json': {},
            'status': 'active',
          }),
          guestRepository: _FakeGuestRepository(
            guests: buildGuests(),
            assignments: buildAssignments(),
          ),
          sessionRepository: sessionRepository,
          nfcService: _QueuedNfcService([
            const TagScanResult(
              rawUid: 'TABLE-001',
              normalizedUid: 'TABLE-001',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-EAST',
              normalizedUid: 'PLAYER-EAST',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-SOUTH',
              normalizedUid: 'PLAYER-SOUTH',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-WEST',
              normalizedUid: 'PLAYER-WEST',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-NORTH',
              normalizedUid: 'PLAYER-NORTH',
              isManualEntry: true,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Table Tag'), findsOneWidget);

    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    expect(find.text('Scan East Player Tag'), findsOneWidget);

    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Review Session'), findsOneWidget);
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('Bob Lee'), findsOneWidget);
    expect(find.text('Carol Ng'), findsOneWidget);
    expect(find.text('Dee Wu'), findsOneWidget);

    await tester.tap(find.text('Confirm Start Session'));
    await tester.pumpAndSettle();

    expect(sessionRepository.startedInput, isNotNull);
    expect(sessionRepository.startedInput!.scannedTableUid, 'TABLE-001');
    expect(sessionRepository.startedInput!.eastPlayerUid, 'PLAYER-EAST');
  });

  testWidgets('shows an inline error for a duplicate player scan',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartSessionScreen(
          eventId: 'evt_01',
          table: EventTableRecord.fromJson(const {
            'id': 'tbl_01',
            'event_id': 'evt_01',
            'label': 'Table 1',
            'mode': 'points',
            'display_order': 1,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'default_rotation_policy_type':
                'dealer_cycle_return_to_initial_east',
            'default_rotation_policy_config_json': {},
            'status': 'active',
          }),
          guestRepository: _FakeGuestRepository(
            guests: buildGuests(),
            assignments: buildAssignments(),
          ),
          sessionRepository: _FakeSessionRepository(),
          nfcService: _QueuedNfcService([
            const TagScanResult(
              rawUid: 'TABLE-001',
              normalizedUid: 'TABLE-001',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-EAST',
              normalizedUid: 'PLAYER-EAST',
              isManualEntry: true,
            ),
            const TagScanResult(
              rawUid: 'PLAYER-EAST',
              normalizedUid: 'PLAYER-EAST',
              isManualEntry: true,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();

    expect(
      find.text('Duplicate player tag scanned in the same session setup.'),
      findsOneWidget,
    );
  });
}
