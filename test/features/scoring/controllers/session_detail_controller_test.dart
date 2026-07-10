import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/session_sync_status.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/session_detail_controller.dart';

void main() {
  test('renders cached session and guest names when remote loads fail',
      () async {
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'cached_hand'),
      loadError: const NetworkUnavailableException('offline'),
    );
    final guests = _FakeGuestRepository(
      cachedGuests: [_guest(id: 'gst_east', name: 'Augustine Liu')],
      loadError: const NetworkUnavailableException('offline'),
    );
    final controller = SessionDetailController(
      guestRepository: guests,
      sessionRepository: sessions,
    );

    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');

    expect(controller.detail!.hands.single.id, 'cached_hand');
    expect(controller.guestNamesById['gst_east'], 'Augustine Liu');
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('terminal sync change quietly reloads detail once', () async {
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'pending:mut_01'),
      loadedDetail: _detail(handId: 'remote_hand_01'),
      snapshots: [
        SessionSyncSnapshot(
          sessionId: 'ses_01',
          pendingHandIds: const {'pending:mut_01'},
          pendingCount: 1,
        ),
        SessionSyncSnapshot(
          sessionId: 'ses_01',
          pendingHandIds: const {'pending:mut_01'},
          pendingCount: 1,
        ),
        SessionSyncSnapshot(sessionId: 'ses_01'),
      ],
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(cachedGuests: [_guest()]),
      sessionRepository: sessions,
    );
    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');
    final initialLoadCount = sessions.loadCount;

    sessions.emitChange();
    await pumpEventQueue();

    expect(controller.detail!.hands.single.id, 'remote_hand_01');
    expect(controller.isLoading, isFalse);
    expect(sessions.loadCount, initialLoadCount + 1);
    controller.dispose();
  });

  test('shows cached detail while remote detail is still pending', () async {
    final remoteGate = Completer<SessionDetailRecord>();
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'cached_hand'),
      blockedInitialDetail: remoteGate,
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(cachedGuests: [_guest()]),
      sessionRepository: sessions,
    );

    final loadFuture = controller.load(
      eventId: 'evt_01',
      sessionId: 'ses_01',
    );
    await pumpEventQueue();

    expect(controller.detail!.hands.single.id, 'cached_hand');
    expect(controller.isLoading, isFalse);

    remoteGate.complete(_detail(handId: 'remote_hand'));
    await loadFuture;
    controller.dispose();
  });

  test('does not let the initial remote result overwrite a quiet refresh',
      () async {
    final initialRemoteGate = Completer<SessionDetailRecord>();
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'pending:mut_01'),
      blockedInitialDetail: initialRemoteGate,
      quietRefreshDetail: _detail(handId: 'remote_hand'),
      snapshots: [
        SessionSyncSnapshot(
          sessionId: 'ses_01',
          pendingHandIds: const {'pending:mut_01'},
          pendingCount: 1,
        ),
        SessionSyncSnapshot(
          sessionId: 'ses_01',
          pendingHandIds: const {'pending:mut_01'},
          pendingCount: 1,
        ),
        SessionSyncSnapshot(sessionId: 'ses_01'),
      ],
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(cachedGuests: [_guest()]),
      sessionRepository: sessions,
    );

    final loadFuture = controller.load(
      eventId: 'evt_01',
      sessionId: 'ses_01',
    );
    await pumpEventQueue();
    sessions.emitChange();
    await pumpEventQueue();

    expect(controller.detail!.hands.single.id, 'remote_hand');
    initialRemoteGate.complete(_detail(handId: 'pending:mut_01'));
    await loadFuture;

    expect(controller.detail!.hands.single.id, 'remote_hand');
    controller.dispose();
  });

  test('recovery rereads the complete sync snapshot after subscription handoff',
      () async {
    final initial = SessionSyncSnapshot(
      sessionId: 'ses_01',
      pendingHandIds: const {'pending:mut_01'},
      pendingCount: 1,
    );
    final latest = SessionSyncSnapshot(
      sessionId: 'ses_01',
      blockedPhotoClientIds: const {'photo_01'},
      photoBlockedReason: 'Photo is unavailable.',
    );
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'cached_hand'),
      snapshots: [initial, latest],
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(cachedGuests: [_guest()]),
      sessionRepository: sessions,
    );

    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');
    await controller.refreshAfterRecovery();

    expect(controller.syncSnapshot?.pendingHandIds, isEmpty);
    expect(controller.syncSnapshot?.blockedPhotoClientIds, {'photo_01'});
    expect(controller.syncSnapshot?.photoBlockedReason, 'Photo is unavailable.');
    controller.dispose();
  });

  test('queues a sync event that arrives during snapshot refresh', () async {
    final initial = SessionSyncSnapshot(
      sessionId: 'ses_01',
      pendingHandIds: const {'pending:mut_01'},
      pendingCount: 1,
    );
    final latest = SessionSyncSnapshot(sessionId: 'ses_01');
    final sessions = _FakeSyncSessionRepository(
      cachedDetail: _detail(handId: 'pending:mut_01'),
      loadedDetail: _detail(handId: 'remote_hand_01'),
      snapshots: [initial, latest, latest],
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(cachedGuests: [_guest()]),
      sessionRepository: sessions,
    );
    await controller.load(eventId: 'evt_01', sessionId: 'ses_01');

    final snapshotGate = Completer<SessionSyncSnapshot>();
    sessions.snapshotGate = snapshotGate;
    sessions.emitChange();
    await pumpEventQueue();
    sessions.emitChange();
    await pumpEventQueue();
    snapshotGate.complete(latest);
    await pumpEventQueue(times: 6);

    expect(sessions.snapshotReadCount, 4);
    expect(controller.syncSnapshot?.pendingHandIds, isEmpty);
    controller.dispose();
  });
}

Future<void> pumpEventQueue({int times = 3}) async {
  for (var index = 0; index < times; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository({
    this.cachedGuests = const [],
    this.loadError,
  });

  final List<EventGuestRecord> cachedGuests;
  final Object? loadError;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async {
    return cachedGuests;
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    if (loadError != null) {
      throw loadError!;
    }
    return cachedGuests;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSyncSessionRepository
    implements SessionRepository, SessionSyncStatusProvider {
  _FakeSyncSessionRepository({
    this.cachedDetail,
    this.loadedDetail,
    this.loadError,
    this.snapshots = const [],
    this.blockedInitialDetail,
    this.quietRefreshDetail,
  });

  final SessionDetailRecord? cachedDetail;
  final SessionDetailRecord? loadedDetail;
  final Object? loadError;
  final List<SessionSyncSnapshot> snapshots;
  final Completer<SessionDetailRecord>? blockedInitialDetail;
  final SessionDetailRecord? quietRefreshDetail;
  final _changes = StreamController<void>.broadcast();
  int loadCount = 0;
  int snapshotReadCount = 0;
  Completer<SessionSyncSnapshot>? snapshotGate;
  int _snapshotIndex = 0;

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId) async {
    return cachedDetail;
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    loadCount += 1;
    if (loadCount == 1 && blockedInitialDetail != null) {
      return blockedInitialDetail!.future;
    }
    if (loadCount == 2 && quietRefreshDetail != null) {
      return quietRefreshDetail!;
    }
    if (loadError != null) {
      throw loadError!;
    }
    return loadedDetail ?? cachedDetail!;
  }

  @override
  Future<SessionSyncSnapshot> readSessionSyncSnapshot(String sessionId) async {
    snapshotReadCount += 1;
    final gate = snapshotGate;
    if (gate != null) {
      snapshotGate = null;
      return gate.future;
    }
    if (snapshots.isEmpty) {
      return SessionSyncSnapshot(sessionId: sessionId);
    }
    final index = _snapshotIndex.clamp(0, snapshots.length - 1);
    _snapshotIndex += 1;
    return snapshots[index];
  }

  @override
  Stream<void> watchSessionSyncChanges(String sessionId) => _changes.stream;

  @override
  Future<void> retryBlockedPhotoUploads(String sessionId) async {}

  void emitChange() => _changes.add(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

EventGuestRecord _guest({String id = 'gst_east', String name = 'East Player'}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': true,
  });
}

SessionDetailRecord _detail({required String handId}) {
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
      'status': 'active',
      'scoring_phase': 'qualification',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 0,
      'completed_games_count': 0,
      'hand_count': 1,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': const [],
    'hands': [
      {
        'id': handId,
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'washout',
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T19:10:00-07:00',
      },
    ],
    'settlements': const [],
  });
}
