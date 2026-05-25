import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';
import '../../../helpers/repository_fakes.dart';

class _FakeEventRepository extends ThrowingEventRepository {
  _FakeEventRepository({
    required this.cachedEvents,
    this.eventLoader,
  });

  final List<EventRecord> cachedEvents;
  final Future<EventRecord?> Function(String eventId)? eventLoader;
  EventRecord Function(String eventId)? cancelHandler;
  EventRecord Function(String eventId)? revertToDraftHandler;
  EventRecord Function(String eventId)? copyForTestingHandler;
  EventRecord Function(String eventId, EventScoringPhase phase)?
      scoringPhaseHandler;
  void Function(String eventId)? deleteHandler;

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) async {
    final handler = cancelHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) async {
    final handler = revertToDraftHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> copyEventForTesting(String eventId) async {
    final handler = copyForTestingHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final handler = deleteHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    handler(eventId);
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async {
    final loader = eventLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedEvents.where((event) => event.id == eventId).firstOrNull;
  }

  @override
  Future<List<EventRecord>> listEvents() {
    throw UnimplementedError();
  }

  @override
  Future<List<EventRecord>> readCachedEvents() async => cachedEvents;

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> updateEventScoringPhase({
    required String eventId,
    required EventScoringPhase phase,
  }) async {
    final handler = scoringPhaseHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId, phase);
  }

  @override
  Future<EventRecord> startEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository({
    required this.cachedGuests,
    this.guestLoader,
  });

  final List<EventGuestRecord> cachedGuests;
  final Future<List<EventGuestRecord>> Function(String eventId)? guestLoader;

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
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final loader = guestLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedGuests;
  }

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      cachedGuests;

  @override
  Future<List<QualificationLeaderboardRow>> fetchQualificationLeaderboard({
    required String eventId,
  }) async {
    return const [
      QualificationLeaderboardRow(
        eventGuestId: 'gst_brian',
        guestProfileId: 'prf_brian',
        fullName: 'Brian Le',
        tournamentStatus: EventTournamentStatus.qualifying,
        qualificationPoints: 48,
        handsPlayed: 8,
        wins: 2,
        selfDrawWins: 1,
        discardWins: 1,
        rank: 1,
      ),
    ];
  }

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId) {
    throw UnimplementedError();
  }

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

class _FakeLeaderboardRepository extends ThrowingLeaderboardRepository {
  const _FakeLeaderboardRepository({
    required this.cachedEntries,
    required this.remoteEntries,
  });

  final List<LeaderboardEntry> cachedEntries;
  final List<LeaderboardEntry> remoteEntries;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      remoteEntries;

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      cachedEntries;
}

class _FakeSessionRepository extends ThrowingSessionRepository {
  _FakeSessionRepository(this.sessions);

  final List<TableSessionRecord> sessions;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      sessions;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.onGenerate,
    this.onLoadRoundSummary,
    this.cachedRoundSummary,
  });

  final Future<List<SeatingAssignmentRecord>> Function(String eventId)?
      onGenerate;
  final Future<TournamentRoundSummary> Function(String eventId)?
      onLoadRoundSummary;
  final TournamentRoundSummary? cachedRoundSummary;

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    final handler = onGenerate;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async {
    final handler = onLoadRoundSummary;
    if (handler != null) {
      return handler(eventId);
    }
    return cachedRoundSummary ?? TournamentRoundSummary.empty();
  }

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      cachedRoundSummary;
}

TournamentRoundSummary _roundSummary(int roundNumber) {
  return TournamentRoundSummary(
    round: TournamentRoundRecord(
      id: 'round_$roundNumber',
      eventId: 'evt_01',
      roundNumber: roundNumber,
      scoringPhase: EventScoringPhase.tournament,
      status: TournamentRoundStatus.active,
      assignmentRound: roundNumber,
    ),
    assignedTableCount: 1,
    completeTableCount: 0,
    activeTableCount: 1,
    pausedTableCount: 0,
    notStartedTableCount: 0,
    currentRoundTables: const [],
    otherTables: const [],
  );
}

void main() {
  test('loads cached dashboard data when remote fetches fail', () async {
    final cachedEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final cachedGuest = EventGuestRecord.fromJson(const {
      'id': 'gst_01',
      'event_id': 'evt_01',
      'display_name': 'Alice Wong',
      'normalized_name': 'alice wong',
      'attendance_status': 'expected',
      'cover_status': 'paid',
      'cover_amount_cents': 2000,
      'is_comped': false,
      'has_scored_play': false,
    });

    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [cachedEvent],
        eventLoader: (_) async => throw Exception('event fetch failed'),
      ),
      guestRepository: _FakeGuestRepository(
        cachedGuests: [cachedGuest],
        guestLoader: (_) async => throw Exception('guest fetch failed'),
      ),
    );

    await controller.load('evt_01');

    expect(controller.event?.id, 'evt_01');
    expect(controller.guestCount, 1);
    expect(controller.error, isNull);
  });

  test('leader label uses the top qualified leaderboard player', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      leaderboardRepository: const _FakeLeaderboardRepository(
        cachedEntries: [],
        remoteEntries: [
          LeaderboardEntry(
            eventGuestId: 'gst_spike',
            displayName: 'One Hand Spike',
            totalPoints: 50,
            handsPlayed: 1,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            totalPoints: 40,
            handsPlayed: 8,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 2,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_grinder',
            displayName: 'Late Grinder',
            totalPoints: 10,
            handsPlayed: 30,
            handsWon: 3,
            selfDrawWins: 2,
            discardWins: 1,
            rank: 3,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(controller.leaderLabel, 'Brian Le');
  });

  test('defaults to qualification phase and loads qualification leaderboard',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );

    await controller.load('evt_01');

    expect(
        controller.event?.currentScoringPhase, EventScoringPhase.qualification);
    expect(controller.qualificationLeaderboard.single.fullName, 'Brian Le');
    expect(controller.qualificationLeaderboard.single.qualificationPoints, 48);
  });

  test('updates event scoring phase through repository', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.setScoringPhase(EventScoringPhase.tournament);

    expect(controller.event?.currentScoringPhase, EventScoringPhase.tournament);
    expect(controller.lifecycleError, isNull);
  });

  test('blocks scoring phase changes while a session is live', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    var didUpdatePhase = false;
    repository.scoringPhaseHandler = (_, __) {
      didUpdatePhase = true;
      return event;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      sessionRepository: _FakeSessionRepository([
        TableSessionRecord.fromJson(const {
          'id': 'ses_01',
          'event_id': 'evt_01',
          'event_table_id': 'tbl_01',
          'session_number_for_table': 1,
          'ruleset_id': 'HK_STANDARD',
          'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
          'rotation_policy_config_json': {},
          'status': 'active',
          'initial_east_seat_index': 0,
          'current_dealer_seat_index': 0,
          'dealer_pass_count': 0,
          'completed_games_count': 0,
          'hand_count': 0,
          'scoring_phase': 'qualification',
          'started_at': '2026-04-24T19:05:00-07:00',
          'started_by_user_id': 'usr_01',
        }),
      ]),
    );
    await controller.load('evt_01');

    await controller.setScoringPhase(EventScoringPhase.tournament);

    expect(didUpdatePhase, isFalse);
    expect(
        controller.event?.currentScoringPhase, EventScoringPhase.qualification);
    expect(controller.lifecycleError,
        contains(scoringPhaseLiveSessionBlockedMessage));
  });

  test('startTournament delegates the phase transition and generates seating',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final operations = <String>[];
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      operations.add('phase:${eventScoringPhaseToJson(phase)}');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (eventId) async {
          operations.add('generate:$eventId');
          return const [];
        },
      ),
    );
    await controller.load('evt_01');

    final assignments = await controller.startTournament();

    expect(assignments, isEmpty);
    expect(controller.event?.currentScoringPhase, EventScoringPhase.tournament);
    expect(controller.lifecycleError, isNull);
    expect(operations, ['generate:evt_01']);
  });

  test('startTournament keeps qualification phase when generation fails',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final operations = <String>[];
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      operations.add('phase:${eventScoringPhaseToJson(phase)}');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (eventId) async {
          operations.add('generate:$eventId');
          throw StateError(
              'Add or tag more tables before starting this round.');
        },
      ),
    );
    await controller.load('evt_01');

    final assignments = await controller.startTournament();

    expect(assignments, isNull);
    expect(
        controller.event?.currentScoringPhase, EventScoringPhase.qualification);
    expect(
      controller.lifecycleError,
      contains('Add or tag more tables before starting this round.'),
    );
    expect(
      controller.lifecycleError,
      isNot(contains('Tournament mode remains active')),
    );
    expect(operations, ['generate:evt_01']);
  });

  test('startTournament can use repositories attached after controller init',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (_, phase) {
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    var generatedAssignments = false;
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    controller.updateRuntimeRepositories(
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (_) async {
          generatedAssignments = true;
          return const [];
        },
      ),
    );
    final assignments = await controller.startTournament();

    expect(assignments, isEmpty);
    expect(generatedAssignments, isTrue);
    expect(controller.lifecycleError, isNull);
  });

  test('startNextTournamentRound reports missing seating repository', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'tournament',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    final assignments = await controller.startNextTournamentRound();

    expect(assignments, isNull);
    expect(
      controller.lifecycleError,
      'Seating setup is required to start the next tournament round.',
    );
  });

  test('in-flight load cannot overwrite round state after next round starts',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'tournament',
    });
    final remoteEvent = Completer<EventRecord?>();
    var roundLoadCount = 0;
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [event],
        eventLoader: (_) => remoteEvent.future,
      ),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        cachedRoundSummary: _roundSummary(1),
        onGenerate: (_) async => const [],
        onLoadRoundSummary: (_) async {
          roundLoadCount += 1;
          return roundLoadCount == 1 ? _roundSummary(3) : _roundSummary(1);
        },
      ),
    );

    final loadFuture = controller.load('evt_01');
    await Future<void>.delayed(Duration.zero);

    final assignments = await controller.startNextTournamentRound();
    remoteEvent.complete(event);
    await loadFuture;

    expect(assignments, isEmpty);
    expect(controller.tournamentRoundSummary.round?.roundNumber, 3);
    expect(controller.isLoading, isFalse);
  });

  test('cancelEvent updates the event to cancelled', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.cancelHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'cancelled',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.cancelEvent();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.cancelled);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });

  test('deleteEvent removes a draft event', () async {
    final draftEvent = EventRecord.fromJson(const {
      'id': 'evt_00',
      'owner_user_id': 'usr_01',
      'title': 'Draft Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    var deletedEventId = '';
    final repository = _FakeEventRepository(cachedEvents: [draftEvent]);
    repository.deleteHandler = (eventId) {
      deletedEventId = eventId;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_00');

    final deleted = await controller.deleteEvent();

    expect(deleted, isTrue);
    expect(deletedEventId, 'evt_00');
    expect(controller.event, isNull);
    expect(controller.lifecycleError, isNull);
  });

  test('revertToDraft updates an active event to draft', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.revertToDraftHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'draft',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.revertToDraft();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.draft);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });

  test('copyEventForTesting returns the copied draft event', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final copiedEvent = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'id': 'evt_copy',
      'title': 'Friday Night Mahjong Copy',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.copyForTestingHandler = (eventId) {
      expect(eventId, 'evt_01');
      return copiedEvent;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    final result = await controller.copyEventForTesting();

    expect(result, copiedEvent);
    expect(controller.event, activeEvent);
    expect(controller.lifecycleError, isNull);
    expect(controller.isSubmittingLifecycle, isFalse);
  });
}
