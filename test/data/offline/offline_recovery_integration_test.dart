import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';
import 'package:mosaic/data/offline/sync_coordinator.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/session_detail_controller.dart';
import 'package:mosaic/services/media/hand_photo_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recovers a queued winning hand and its photo after reconnect',
      () async {
    final store = await SqliteOfflineStore.inMemory();
    final reachability = _ControllableReachability(reachable: false);
    final onlineRepository = _CanonicalOnlineSessionRepository();
    final evidenceRepository = _FakeEvidenceRepository();
    final photoStorage = _FakePhotoStorage(existing: {'/local/photo.jpg'});
    final offlineRepository = OfflineSessionRepository(
      inner: onlineRepository,
      store: store,
      reachability: reachability,
      newMutationId: () => 'mutation_01',
      now: () => DateTime.utc(2026, 6, 25, 18),
      handPhotoStorage: photoStorage,
    );
    final coordinator = SyncCoordinator(
      store: store,
      reachability: reachability,
      sessionRepository: onlineRepository,
      handEvidenceRepository: evidenceRepository,
      photoStorage: photoStorage,
      now: () => DateTime.utc(2026, 6, 25, 18),
    );
    final controller = SessionDetailController(
      guestRepository: _FakeGuestRepository(),
      sessionRepository: offlineRepository,
    );

    try {
      await coordinator.initialize();
      await controller.load(eventId: 'evt_01', sessionId: 'ses_01');

      expect(controller.detail!.hands, isEmpty);
      final projected = await offlineRepository.recordHand(_winningInput());
      expect(projected.hands.single.id, startsWith('pending:'));
      expect(
        (await offlineRepository.readSessionSyncSnapshot('ses_01'))
            .pendingCount,
        1,
      );

      reachability.reachable = true;
      reachability.emitReachable();
      await pumpEventQueue(times: 10);

      expect(onlineRepository.recordedInputs, hasLength(1));
      expect(evidenceRepository.uploads, hasLength(1));
      expect(coordinator.generation, 1);
      expect(controller.detail!.hands.single.id, 'remote_hand_01');
      expect(controller.syncSnapshot!.pendingCount, 0);
      expect(controller.syncSnapshot!.pendingPhotoCount, 0);
      expect(photoStorage.deletedPaths, ['/local/photo.jpg']);
    } finally {
      controller.dispose();
      await coordinator.dispose();
      await reachability.close();
      await store.close();
    }
  });
}

Future<void> pumpEventQueue({int times = 3}) async {
  for (var index = 0; index < times; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

RecordHandResultInput _winningInput() {
  return RecordHandResultInput(
    tableSessionId: 'ses_01',
    resultType: HandResultType.win,
    winnerSeatIndex: 0,
    winType: HandWinType.selfDraw,
    fanCount: 5,
    photoClientId: 'photo_01',
    photoLocalPath: '/local/photo.jpg',
    photoCapturedAt: DateTime.utc(2026, 6, 25, 18),
  );
}

class _ControllableReachability implements NetworkReachability {
  _ControllableReachability({required this.reachable})
      : _events = StreamController<void>.broadcast(sync: true);

  bool reachable;
  final StreamController<void> _events;

  @override
  Stream<void> get onReachable => _events.stream;

  @override
  Future<bool> isReachable() async => reachable;

  @override
  bool isNetworkException(Object error) => error is NetworkUnavailableException;

  void emitReachable() => _events.add(null);

  Future<void> close() => _events.close();
}

class _CanonicalOnlineSessionRepository implements SessionRepository {
  final List<RecordHandResultInput> recordedInputs = [];
  SessionDetailRecord _detail = _emptyDetail();

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    recordedInputs.add(input);
    _detail = _detailWithRemoteHand(input.clientMutationId);
    return _detail;
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      _emptyDetail();

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      _detail;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGuestRepository implements GuestRepository {
  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeEvidenceRepository implements HandEvidenceRepository {
  final List<_Upload> uploads = [];

  @override
  Future<void> uploadAndAttachHandPhoto({
    required String eventId,
    required String handResultId,
    required String clientPhotoId,
    required String localPath,
    required DateTime capturedAt,
  }) async {
    uploads.add(
      _Upload(
        eventId: eventId,
        handResultId: handResultId,
        clientPhotoId: clientPhotoId,
        localPath: localPath,
        capturedAt: capturedAt,
      ),
    );
  }
}

class _Upload {
  const _Upload({
    required this.eventId,
    required this.handResultId,
    required this.clientPhotoId,
    required this.localPath,
    required this.capturedAt,
  });

  final String eventId;
  final String handResultId;
  final String clientPhotoId;
  final String localPath;
  final DateTime capturedAt;
}

class _FakePhotoStorage implements HandPhotoStorage {
  _FakePhotoStorage({required Set<String> existing})
      : _existing = {...existing};

  final Set<String> _existing;
  final List<String> deletedPaths = [];

  @override
  Future<bool> exists(String path) async => _existing.contains(path);

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
    _existing.remove(path);
  }

  @override
  Future<String> persist({
    required String sourcePath,
    required String photoId,
  }) async {
    _existing.add(sourcePath);
    return sourcePath;
  }
}

SessionDetailRecord _emptyDetail() {
  return SessionDetailRecord.fromJson(const {
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
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 0,
      'completed_games_count': 0,
      'hand_count': 0,
      'started_at': '2026-06-25T18:00:00Z',
      'started_by_user_id': 'usr_01',
    },
    'seats': [],
    'hands': [],
    'settlements': [],
  });
}

SessionDetailRecord _detailWithRemoteHand(String? clientMutationId) {
  return SessionDetailRecord.fromJson({
    ..._emptyDetail().toJson(),
    'session': {
      ..._emptyDetail().session.toJson(),
      'hand_count': 1,
      'completed_games_count': 1,
    },
    'hands': [
      {
        'id': 'remote_hand_01',
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'win',
        'winner_seat_index': 0,
        'win_type': 'self_draw',
        'fan_count': 5,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 1,
        'dealer_rotated': true,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-06-25T18:00:00Z',
        'client_mutation_id': clientMutationId,
        'photo_client_id': 'photo_01',
        'photo_captured_at': '2026-06-25T18:00:00Z',
      },
    ],
  });
}
