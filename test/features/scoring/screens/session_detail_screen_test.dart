import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';

class _FakeGuestRepository implements GuestRepository {
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
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [
        {
          'id': 'gst_east',
          'event_id': 'evt_01',
          'display_name': 'Alice Wong',
          'normalized_name': 'alice wong',
          'attendance_status': 'checked_in',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': true,
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
          'has_scored_play': true,
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
          'has_scored_play': true,
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
          'has_scored_play': true,
        },
      ].map(EventGuestRecord.fromJson).toList(growable: false);

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      listGuests(eventId);

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
  _FakeSessionRepository({required this.detail});

  SessionDetailRecord detail;
  String? endedReason;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) async {
    endedReason = reason;
    detail = SessionDetailRecord.fromJson({
      ...detail.toJson(),
      'session': {
        ...detail.session.toJson(),
        'status': 'ended_early',
        'ended_at': '2026-04-24T20:00:00-07:00',
        'ended_by_user_id': 'usr_01',
        'end_reason': reason,
      },
    });
    return detail;
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      detail;

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async {
    detail = SessionDetailRecord.fromJson({
      ...detail.toJson(),
      'session': {
        ...detail.session.toJson(),
        'status': 'paused',
      },
    });
    return detail;
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async {
    detail = SessionDetailRecord.fromJson({
      ...detail.toJson(),
      'session': {
        ...detail.session.toJson(),
        'status': 'active',
      },
    });
    return detail;
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
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

SessionDetailRecord _buildDetail(SessionStatus status) {
  return SessionDetailRecord.fromJson({
    'session': {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD_V1',
      'ruleset_version': 1,
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': switch (status) {
        SessionStatus.active => 'active',
        SessionStatus.paused => 'paused',
        SessionStatus.completed => 'completed',
        SessionStatus.endedEarly => 'ended_early',
        SessionStatus.aborted => 'aborted',
      },
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 1,
      'dealer_pass_count': 1,
      'completed_games_count': 1,
      'hand_count': 1,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': [
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
    'hands': [
      {
        'id': 'hand_01',
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'win',
        'winner_seat_index': 2,
        'win_type': 'discard',
        'discarder_seat_index': 0,
        'fan_count': 2,
        'base_points': 4,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 1,
        'dealer_rotated': true,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T19:05:00-07:00',
      },
    ],
    'settlements': [
      {
        'id': 'set_01',
        'hand_result_id': 'hand_01',
        'payer_event_guest_id': 'gst_east',
        'payee_event_guest_id': 'gst_west',
        'amount_points': 16,
        'multiplier_flags_json': ['discard', 'east_loses'],
      },
    ],
  });
}

void main() {
  testWidgets('active session shows pause and end controls', (tester) async {
    final sessionRepository = _FakeSessionRepository(
      detail: _buildDetail(SessionStatus.active),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: sessionRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session Status'), findsOneWidget);
    expect(find.text('Active Session'), findsOneWidget);
    expect(find.text('Current East'), findsOneWidget);
    expect(find.text('Current East Seat'), findsOneWidget);
    expect(find.text('Bob Lee'), findsWidgets);
    expect(find.text('Pause Session'), findsOneWidget);
    expect(find.text('End Early'), findsOneWidget);
    expect(find.text('Resume Session'), findsNothing);

    await tester.tap(find.text('Record Hand'));
    await tester.pumpAndSettle();

    expect(find.text('Record Hand'), findsOneWidget);
  });

  testWidgets('paused session shows resume and blocks record hand',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(SessionStatus.paused),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paused Session'), findsOneWidget);
    expect(
      find.text('Hand entry is unavailable while this session is paused.'),
      findsOneWidget,
    );
    expect(find.text('Resume Session'), findsOneWidget);
    expect(find.text('Pause Session'), findsNothing);
    expect(find.text('End Early'), findsOneWidget);
    expect(find.text('Record Hand'), findsNothing);
  });

  testWidgets('end early requires a reason', (tester) async {
    final sessionRepository = _FakeSessionRepository(
      detail: _buildDetail(SessionStatus.active),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: sessionRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Early'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();

    expect(find.text('Reason is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Venue closing');
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();

    expect(sessionRepository.endedReason, 'Venue closing');
    expect(find.text('Ended Early'), findsOneWidget);
    expect(find.text('Session ended early: Venue closing'), findsOneWidget);
  });
}
