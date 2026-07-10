import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/offline/offline_recovery_signal.dart';
import 'package:mosaic/data/offline/session_sync_status.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/session_detail_controller.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';

class _FakeGuestRepository implements GuestRepository {
  Completer<List<EventGuestRecord>>? listGuestsGate;
  List<EventGuestRecord>? remoteGuestsOverride;

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
  Future<EventGuestRecord> undoGuestCheckIn(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> createGuests(BulkCreateGuestsInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final gate = listGuestsGate;
    if (gate != null) {
      return gate.future;
    }
    return remoteGuestsOverride ?? _defaultGuests();
  }

  List<EventGuestRecord> _defaultGuests() => const [
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
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      _defaultGuests();

  @override
  Future<List<GuestProfileRecord>> listGuestProfiles() async => const [];

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
  Future<GuestDetailRecord> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository
    implements SessionRepository, SessionSyncStatusProvider {
  _FakeSessionRepository({
    required this.detail,
    SessionSyncSnapshot? syncSnapshot,
    this.cachedDetail,
    this.remoteDetailGate,
  }) : syncSnapshot =
            syncSnapshot ?? SessionSyncSnapshot(sessionId: detail.session.id);

  SessionDetailRecord detail;
  final SessionDetailRecord? cachedDetail;
  Completer<SessionDetailRecord>? remoteDetailGate;
  SessionSyncSnapshot syncSnapshot;
  StreamController<void>? syncChangesController;
  SessionDetailRecord? recordHandDetail;
  bool remoteFail = false;
  String? endedReason;
  int retryBlockedPhotoUploadsCount = 0;
  int loadSessionDetailCount = 0;

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
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    loadSessionDetailCount += 1;
    if (remoteFail) {
      throw Exception('temporary session detail failure');
    }
    final gate = remoteDetailGate;
    if (gate != null) {
      return gate.future;
    }
    return detail;
  }

  @override
  Future<SessionSyncSnapshot> readSessionSyncSnapshot(String sessionId) async =>
      syncSnapshot;

  @override
  Stream<void> watchSessionSyncChanges(String sessionId) =>
      syncChangesController?.stream ?? const Stream.empty();

  @override
  Future<void> retryBlockedPhotoUploads(String sessionId) async {
    retryBlockedPhotoUploadsCount += 1;
  }

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
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    detail = recordHandDetail ?? detail;
    return detail;
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      cachedDetail;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _FakeOfflineRecoverySignal implements OfflineRecoverySignal {
  final _controller = StreamController<int>.broadcast();
  var _generation = 0;

  @override
  int get generation => _generation;

  @override
  Stream<int> get generations => _controller.stream;

  void emit() {
    _generation += 1;
    _controller.add(_generation);
  }

  void dispose() => _controller.close();
}

SessionDetailRecord _buildDetail(
  SessionStatus status, {
  bool hasHands = true,
  String startedAt = '2026-04-24T19:00:00-07:00',
  EventScoringPhase scoringPhase = EventScoringPhase.qualification,
  int? assignmentRound,
  int currentDealerSeatIndex = 1,
  List<Map<String, Object?>>? hands,
}) {
  return SessionDetailRecord.fromJson({
    'table_label': 'Table 1',
    'session': {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': switch (status) {
        SessionStatus.active => 'active',
        SessionStatus.paused => 'paused',
        SessionStatus.completed => 'completed',
        SessionStatus.endedEarly => 'ended_early',
        SessionStatus.aborted => 'aborted',
      },
      'scoring_phase': eventScoringPhaseToJson(scoringPhase),
      'assignment_round': assignmentRound,
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': currentDealerSeatIndex,
      'dealer_pass_count': 1,
      'completed_games_count': 1,
      'hand_count': hasHands ? 1 : 0,
      'started_at': startedAt,
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
    'hands': hasHands
        ? hands ??
            [
              {
                'id': 'hand_01',
                'table_session_id': 'ses_01',
                'hand_number': 1,
                'result_type': 'win',
                'winner_seat_index': 2,
                'win_type': 'discard',
                'discarder_seat_index': 0,
                'fan_count': 3,
                'base_points': 8,
                'east_seat_index_before_hand': 0,
                'east_seat_index_after_hand': 1,
                'dealer_rotated': true,
                'session_completed_after_hand': false,
                'status': 'recorded',
                'entered_by_user_id': 'usr_01',
                'entered_at': '2026-04-24T19:05:00-07:00',
              },
            ]
        : [],
    'settlements': hasHands
        ? [
            {
              'id': 'set_01',
              'hand_result_id': 'hand_01',
              'payer_event_guest_id': 'gst_east',
              'payee_event_guest_id': 'gst_west',
              'amount_points': 16,
              'multiplier_flags_json': ['discard', 'east_loses'],
            },
          ]
        : [],
  });
}

EventGuestRecord _guestRecord(String id, String name) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': true,
  });
}

SessionDetailRecord _detailWithPhoto({required String clientPhotoId}) {
  return _buildDetail(
    SessionStatus.active,
    hands: [
      {
        'id': 'hand_01',
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'win',
        'winner_seat_index': 2,
        'win_type': 'discard',
        'discarder_seat_index': 0,
        'fan_count': 3,
        'base_points': 8,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 1,
        'dealer_rotated': true,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T19:05:00-07:00',
        'photo_client_id': clientPhotoId,
      },
    ],
  );
}

void main() {
  testWidgets('clears initial loading when detail arrives before guests',
      (tester) async {
    final guestRepository = _FakeGuestRepository()
      ..listGuestsGate = Completer<List<EventGuestRecord>>();
    final detail = _buildDetail(SessionStatus.active);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: guestRepository,
          sessionRepository: _FakeSessionRepository(detail: detail),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);

    guestRepository.listGuestsGate!.complete(guestRepository._defaultGuests());
    await tester.pumpAndSettle();
  });

  test('refresh reports an error when no detail is available', () async {
    final detail = _buildDetail(SessionStatus.active);
    final repository = _FakeSessionRepository(detail: detail);
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(),
      sessionRepository: repository,
    );
    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');

    controller.detail = null;
    repository.remoteFail = true;
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);
    await controller.refreshAfterRecovery();

    expect(controller.error, contains('temporary session detail failure'));
    expect(notificationCount, greaterThan(0));
    controller.dispose();
  });

  test('recovery resets an in-flight sync refresh guard', () async {
    final detail = _buildDetail(SessionStatus.active);
    final syncChanges = StreamController<void>.broadcast();
    final repository = _FakeSessionRepository(
      detail: detail,
      syncSnapshot: SessionSyncSnapshot(
        sessionId: 'ses_01',
        pendingHandIds: const {'hand_01'},
      ),
    )..syncChangesController = syncChanges;
    addTearDown(syncChanges.close);
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(),
      sessionRepository: repository,
    );
    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');

    final firstRefreshGate = Completer<SessionDetailRecord>();
    repository.remoteDetailGate = firstRefreshGate;
    repository.syncSnapshot = SessionSyncSnapshot(sessionId: 'ses_01');
    syncChanges.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final recoveryFuture = controller.refreshAfterRecovery();
    await Future<void>.delayed(Duration.zero);
    firstRefreshGate.complete(detail);
    await recoveryFuture;

    final secondRefreshGate = Completer<SessionDetailRecord>();
    repository.remoteDetailGate = secondRefreshGate;
    repository.syncSnapshot = SessionSyncSnapshot(
      sessionId: 'ses_01',
      pendingHandIds: const {'hand_01'},
    );
    syncChanges.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    repository.syncSnapshot = SessionSyncSnapshot(sessionId: 'ses_01');
    syncChanges.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(repository.loadSessionDetailCount, 4);

    secondRefreshGate.complete(detail);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
  });

  testWidgets('reconnect silently refreshes session detail without queued rows',
      (tester) async {
    final cachedDetail = _buildDetail(SessionStatus.active, hasHands: false);
    final guestRepository = _FakeGuestRepository();
    final repository = _FakeSessionRepository(
      detail: cachedDetail,
      cachedDetail: cachedDetail,
    );
    final signal = _FakeOfflineRecoverySignal();
    addTearDown(signal.dispose);

    await tester.pumpWidget(
      OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          home: SessionDetailScreen(
            eventId: 'evt_01',
            sessionId: 'ses_01',
            guestRepository: guestRepository,
            sessionRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.detail = _buildDetail(SessionStatus.active);
    guestRepository.remoteGuestsOverride = [
      _guestRecord('gst_east', 'Alice Updated'),
      _guestRecord('gst_south', 'Bob Lee'),
      _guestRecord('gst_west', 'Carol Ng'),
      _guestRecord('gst_north', 'Dee Wu'),
    ];
    signal.emit();
    await tester.pumpAndSettle();

    expect(repository.loadSessionDetailCount, 2);
    expect(find.text('Hand 1'), findsWidgets);
    expect(find.text('Alice Updated'), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);
  });

  testWidgets('keeps cached session visible while remote detail is pending',
      (tester) async {
    final cachedDetail = _buildDetail(SessionStatus.active);
    final remoteDetailGate = Completer<SessionDetailRecord>();
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: cachedDetail,
            cachedDetail: cachedDetail,
            remoteDetailGate: remoteDetailGate,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);

    remoteDetailGate.complete(cachedDetail);
    await tester.pumpAndSettle();
  });

  testWidgets('active session renders live console context and actions',
      (tester) async {
    final sessionRepository = _FakeSessionRepository(
      detail: _buildDetail(
        SessionStatus.active,
        scoringPhase: EventScoringPhase.tournament,
      ),
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

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.textContaining('Current session'), findsOneWidget);
    expect(find.text('Session Detail'), findsNothing);
    expect(find.text('Current East'), findsNothing);
    expect(find.text('SOUTH · CURRENT EAST'), findsNothing);
    expect(find.text('Round Wind: East'), findsOneWidget);
    expect(find.text('Dealer: Bob'), findsOneWidget);
    expect(find.text('SOUTH'), findsOneWidget);
    expect(find.text('Dealer'), findsOneWidget);
    expect(find.text('Record Hand'), findsOneWidget);
    expect(find.text('Pause Timer'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.text('Resume Timer'), findsNothing);
  });

  testWidgets('round timer counts down while session detail is open',
      (tester) async {
    var now = DateTime.parse('2026-05-21T12:59:58Z');
    final startedAt = DateTime.parse('2026-05-21T12:00:00Z').toIso8601String();
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              scoringPhase: EventScoringPhase.tournament,
              startedAt: startedAt,
            ),
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('00:02'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Time expired'), findsOneWidget);
  });

  testWidgets('timed completed session allows missing final hand entry',
      (tester) async {
    final startedAt =
        DateTime.now().subtract(const Duration(minutes: 61)).toIso8601String();

    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.completed,
              scoringPhase: EventScoringPhase.tournament,
              startedAt: startedAt,
              hands: const [
                {
                  'id': 'hand_01',
                  'table_session_id': 'ses_01',
                  'hand_number': 1,
                  'result_type': 'washout',
                  'east_seat_index_before_hand': 0,
                  'east_seat_index_after_hand': 1,
                  'dealer_rotated': true,
                  'session_completed_after_hand': false,
                  'status': 'recorded',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:05:00-07:00',
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Record Hand'), findsOneWidget);
    expect(
      find.text('Hand entry is closed because this session is complete.'),
      findsNothing,
    );
  });

  testWidgets('final hand completion blocks further hand entry',
      (tester) async {
    final startedAt =
        DateTime.now().subtract(const Duration(minutes: 61)).toIso8601String();
    final sessionRepository = _FakeSessionRepository(
      detail: _buildDetail(
        SessionStatus.completed,
        scoringPhase: EventScoringPhase.tournament,
        startedAt: startedAt,
        currentDealerSeatIndex: 0,
        hands: const [
          {
            'id': 'hand_01',
            'table_session_id': 'ses_01',
            'hand_number': 1,
            'result_type': 'win',
            'winner_seat_index': 0,
            'win_type': 'self_draw',
            'discarder_seat_index': null,
            'fan_count': 3,
            'base_points': 8,
            'east_seat_index_before_hand': 0,
            'east_seat_index_after_hand': 0,
            'dealer_rotated': false,
            'session_completed_after_hand': true,
            'status': 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:05:00-07:00',
          },
        ],
      ),
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

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Record Hand'), findsNothing);
  });

  testWidgets('tournament session shows assignment round wind before hands',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              hasHands: false,
              scoringPhase: EventScoringPhase.tournament,
              assignmentRound: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round Wind: South'), findsOneWidget);
  });

  testWidgets('seat grid arranges seats counter-clockwise around the table',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(SessionStatus.active, hasHands: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alice = tester.getCenter(find.text('Alice Wong'));
    final bob = tester.getCenter(find.text('Bob Lee'));
    final carol = tester.getCenter(find.text('Carol Ng'));
    final dee = tester.getCenter(find.text('Dee Wu'));

    expect(alice.dx, lessThan(dee.dx));
    expect(alice.dy, lessThan(bob.dy));
    expect(bob.dx, lessThan(carol.dx));
    expect(dee.dy, lessThan(carol.dy));
  });

  testWidgets('active session shows round timer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              scoringPhase: EventScoringPhase.tournament,
              startedAt: DateTime.now()
                  .subtract(const Duration(minutes: 40))
                  .toIso8601String(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round Time'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
  });

  testWidgets('qualification session hides round timer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              scoringPhase: EventScoringPhase.qualification,
              startedAt: DateTime.now()
                  .subtract(const Duration(minutes: 61))
                  .toIso8601String(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round Time'), findsNothing);
    expect(find.text('Time expired'), findsNothing);
    expect(find.text('Pause Timer'), findsNothing);
    expect(find.text('Resume Timer'), findsNothing);
  });

  testWidgets('active session blocks hand entry when scoring is paused',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          scoringOpen: false,
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              scoringPhase: EventScoringPhase.tournament,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(
      find.text('Hand entry is unavailable while scoring is paused.'),
      findsOneWidget,
    );
    expect(find.text('Record Hand'), findsNothing);
    expect(find.text('Pause Timer'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hand 1'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Hand'), findsNothing);
  });

  testWidgets('hand history uses session detail hand summaries',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(SessionStatus.active),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Hand 1'), findsOneWidget);
    expect(
      find.text(
        'Carol Ng won by discard · 3 fan · Alice Wong discarded · '
        'East rotated · Carol Ng +16',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pending offline hand sync state renders count and hand chip',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              hands: const [
                {
                  'id': 'pending:mut_01',
                  'table_session_id': 'ses_01',
                  'hand_number': 1,
                  'result_type': 'washout',
                  'east_seat_index_before_hand': 0,
                  'east_seat_index_after_hand': 1,
                  'dealer_rotated': true,
                  'session_completed_after_hand': false,
                  'status': 'recorded',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:05:00-07:00',
                },
              ],
            ),
            syncSnapshot: SessionSyncSnapshot(
              sessionId: 'ses_01',
              pendingHandIds: const {'pending:mut_01'},
              pendingCount: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 hand pending sync'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets(
      'blocked offline hand sync state requires review and disables hand entry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              hands: const [
                {
                  'id': 'pending:mut_01',
                  'table_session_id': 'ses_01',
                  'hand_number': 1,
                  'result_type': 'washout',
                  'east_seat_index_before_hand': 0,
                  'east_seat_index_after_hand': 1,
                  'dealer_rotated': true,
                  'session_completed_after_hand': false,
                  'status': 'recorded',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:05:00-07:00',
                },
              ],
            ),
            syncSnapshot: SessionSyncSnapshot(
              sessionId: 'ses_01',
              blockedHandIds: const {'pending:mut_01'},
              isBlocked: true,
              blockedReason: 'Current session hand count has changed.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('needs review'), findsOneWidget);
    expect(find.text('Record Hand'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Blocked'), findsOneWidget);
  });

  testWidgets('photo warning keeps Record Hand enabled and retries',
      (tester) async {
    final repository = _FakeSessionRepository(
      detail: _detailWithPhoto(clientPhotoId: 'photo_01'),
      syncSnapshot: SessionSyncSnapshot(
        sessionId: 'ses_01',
        blockedPhotoClientIds: const {'photo_01'},
        photoBlockedReason: 'storage rejected upload',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo upload needs attention'), findsOneWidget);
    expect(find.text('Record Hand'), findsOneWidget);
    await tester.tap(find.text('Retry Upload'));
    await tester.pump();
    expect(repository.retryBlockedPhotoUploadsCount, 1);
  });

  testWidgets('voided hands render in a separate archive section',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(
              SessionStatus.active,
              hands: const [
                {
                  'id': 'hand_01',
                  'table_session_id': 'ses_01',
                  'hand_number': 1,
                  'result_type': 'win',
                  'winner_seat_index': 2,
                  'win_type': 'discard',
                  'discarder_seat_index': 0,
                  'fan_count': 3,
                  'base_points': 8,
                  'east_seat_index_before_hand': 0,
                  'east_seat_index_after_hand': 1,
                  'dealer_rotated': true,
                  'session_completed_after_hand': false,
                  'status': 'recorded',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:05:00-07:00',
                },
                {
                  'id': 'hand_02',
                  'table_session_id': 'ses_01',
                  'hand_number': 2,
                  'result_type': 'win',
                  'winner_seat_index': 1,
                  'win_type': 'self_draw',
                  'discarder_seat_index': null,
                  'fan_count': 3,
                  'base_points': 8,
                  'east_seat_index_before_hand': 1,
                  'east_seat_index_after_hand': 1,
                  'dealer_rotated': false,
                  'session_completed_after_hand': false,
                  'status': 'voided',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:10:00-07:00',
                  'correction_note': 'Incorrect result',
                },
                {
                  'id': 'hand_03',
                  'table_session_id': 'ses_01',
                  'hand_number': 2,
                  'result_type': 'washout',
                  'east_seat_index_before_hand': 1,
                  'east_seat_index_after_hand': 2,
                  'dealer_rotated': true,
                  'session_completed_after_hand': false,
                  'status': 'recorded',
                  'entered_by_user_id': 'usr_01',
                  'entered_at': '2026-04-24T19:15:00-07:00',
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Hand 1'), findsOneWidget);
    expect(find.text('Hand 2'), findsOneWidget);
    expect(find.text('Voided Hands'), findsOneWidget);
    expect(find.text('Voided Hand 2'), findsOneWidget);
    expect(find.text('Voided · Incorrect result'), findsOneWidget);
  });

  testWidgets('tapping hand history opens edit hand entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(SessionStatus.active),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 1'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Hand'), findsOneWidget);
    expect(find.text('Void Hand'), findsOneWidget);
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
            detail: _buildDetail(
              SessionStatus.paused,
              scoringPhase: EventScoringPhase.tournament,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(
      find.text('Hand entry is unavailable while this session is paused.'),
      findsOneWidget,
    );
    expect(find.text('Resume Timer'), findsOneWidget);
    expect(find.text('Pause Timer'), findsNothing);
    expect(find.text('End'), findsOneWidget);
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

    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();

    expect(find.text('Reason is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Venue closing');
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();

    expect(sessionRepository.endedReason, 'Venue closing');
    expect(find.text('Ended Early'), findsOneWidget);
    expect(find.text('Ended early: Venue closing'), findsOneWidget);
    expect(find.text('Record Hand'), findsNothing);
  });

  testWidgets(
      'active session without hands shows empty state and record action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          eventId: 'evt_01',
          sessionId: 'ses_01',
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            detail: _buildDetail(SessionStatus.active, hasHands: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('No hands recorded yet.'), findsOneWidget);
    expect(find.text('Record Hand'), findsOneWidget);
  });
}
