import 'dart:async';

import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_session_projector.dart';
import 'package:mosaic/data/offline/offline_store.dart';
import 'package:mosaic/data/offline/session_sync_status.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:uuid/uuid.dart';

class OfflineSessionRepository
    implements
        SessionRepository,
        FalseWinPenaltyCorrectionRepository,
        SessionSyncStatusProvider {
  OfflineSessionRepository({
    required this.inner,
    required this.store,
    required this.reachability,
    this.projector = const OfflineSessionProjector(),
    String Function()? newMutationId,
    DateTime Function()? now,
    Future<void> Function()? onMutationQueued,
  })  : _newMutationId = newMutationId ?? const Uuid().v4,
        _now = now ?? DateTime.now,
        _onMutationQueued = onMutationQueued;

  final SessionRepository inner;
  final OfflineStore store;
  final NetworkReachability reachability;
  final OfflineSessionProjector projector;
  final String Function() _newMutationId;
  final DateTime Function() _now;
  final Future<void> Function()? _onMutationQueued;

  @override
  Future<SessionSyncSnapshot> readSessionSyncSnapshot(String sessionId) async {
    final mutations = await store.readMutationsForSession(sessionId);
    return _snapshotFromMutations(sessionId, mutations);
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId) async {
    final detail = await inner.readCachedSessionDetail(sessionId);
    if (detail == null) {
      return null;
    }
    return (await _project(detail)).detail;
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    if (await reachability.isReachable()) {
      try {
        return (await _project(await inner.loadSessionDetail(sessionId)))
            .detail;
      } catch (error) {
        if (!reachability.isNetworkException(error)) {
          rethrow;
        }
      }
    }

    final cached = await inner.readCachedSessionDetail(sessionId);
    if (cached == null) {
      throw StateError('This session is not available offline yet.');
    }
    return (await _project(cached)).detail;
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    if (_shouldEnqueuePhotoUpload(input)) {
      return _enqueueRecordHand(input);
    }

    if (await _hasQueuedMutations(input.tableSessionId)) {
      return _enqueueRecordHand(input);
    }

    if (await reachability.isReachable()) {
      try {
        return await inner.recordHand(input);
      } catch (error) {
        if (!reachability.isNetworkException(error)) {
          rethrow;
        }
      }
    }

    return _enqueueRecordHand(input);
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    if (await _hasQueuedMutations(input.tableSessionId)) {
      return _enqueueRecordFalseWinPenalty(input);
    }

    if (await reachability.isReachable()) {
      try {
        return await inner.recordFalseWinPenalty(input);
      } catch (error) {
        if (!reachability.isNetworkException(error)) {
          rethrow;
        }
      }
    }

    return _enqueueRecordFalseWinPenalty(input);
  }

  @override
  Future<SessionDetailRecord> voidFalseWinPenalty(
    VoidFalseWinPenaltyInput input,
  ) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'False win corrections are unavailable while offline.',
      );
    }

    return (inner as FalseWinPenaltyCorrectionRepository)
        .voidFalseWinPenalty(input);
  }

  Future<bool> _hasQueuedMutations(String sessionId) async {
    final mutations = await store.readMutationsForSession(sessionId);
    return mutations.any(
      (mutation) => mutation.status != OfflineMutationStatus.synced,
    );
  }

  Future<SessionDetailRecord> _enqueueRecordHand(
    RecordHandResultInput input,
  ) async {
    final cached = await inner.readCachedSessionDetail(input.tableSessionId);
    if (cached == null) {
      throw StateError('This session is not available offline yet.');
    }

    final existingMutations =
        await store.readMutationsForSession(input.tableSessionId);
    final projectedRecordedHands = _projectedRecordedHands(
      cached,
      existingMutations,
    );
    final projectedLastHand =
        projectedRecordedHands.isEmpty ? null : projectedRecordedHands.last;
    final expectedLastRecordedHandId =
        projectedLastHand == null || projectedLastHand.id.startsWith('pending:')
            ? null
            : projectedLastHand.id;
    final mutationId = _newMutationId();
    final timestamp = _now().toUtc();

    final payload = {
      ...input.toRpcParams(),
      'target_client_mutation_id': mutationId,
      'target_expected_recorded_hand_count': projectedRecordedHands.length,
      'target_expected_last_recorded_hand_id': expectedLastRecordedHandId,
    };

    final mutation = OfflineMutationRecord(
      id: mutationId,
      kind: OfflineMutationKind.recordHand,
      eventId: cached.session.eventId,
      sessionId: input.tableSessionId,
      payload: payload,
      baseRecordedHandCount: projectedRecordedHands.length,
      baseLastRecordedHandId: expectedLastRecordedHandId,
      localHandNumber: projectedRecordedHands.length + 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    if (_shouldEnqueuePhotoUpload(input)) {
      await store.insertMutationWithPhotoUpload(
        mutation,
        OfflinePhotoUploadRecord(
          id: input.photoClientId!,
          mutationId: mutationId,
          eventId: cached.session.eventId,
          sessionId: input.tableSessionId,
          clientPhotoId: input.photoClientId!,
          localPath: input.photoLocalPath!,
          capturedAt: input.photoCapturedAt!.toUtc(),
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    } else {
      await store.insertMutation(mutation);
    }

    final projected = (await _project(cached)).detail;
    _scheduleSync();
    return projected;
  }

  bool _shouldEnqueuePhotoUpload(RecordHandResultInput input) {
    return input.resultType == HandResultType.win &&
        input.photoClientId != null &&
        input.photoLocalPath != null &&
        input.photoCapturedAt != null;
  }

  Future<SessionDetailRecord> _enqueueRecordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    final cached = await inner.readCachedSessionDetail(input.tableSessionId);
    if (cached == null) {
      throw StateError('This session is not available offline yet.');
    }

    final existingMutations =
        await store.readMutationsForSession(input.tableSessionId);
    final currentProjection = projector
        .project(
          detail: cached,
          mutations: existingMutations,
        )
        .detail;
    if (currentProjection.pendingFalseWinPenaltySeatIndexes.contains(
      input.penaltySeatIndex,
    )) {
      throw StateError(
        OfflineSessionProjector.duplicateFalseWinPenaltyMessage,
      );
    }
    final projectedRecordedHands = _recordedHandsExcludingBlocked(
      currentProjection,
      existingMutations,
    );
    final projectedLastHand =
        projectedRecordedHands.isEmpty ? null : projectedRecordedHands.last;
    final expectedLastRecordedHandId =
        projectedLastHand == null || projectedLastHand.id.startsWith('pending:')
            ? null
            : projectedLastHand.id;
    final mutationId = _newMutationId();
    final timestamp = _now().toUtc();
    final payload = {
      ...input.toRpcParams(),
      'target_client_mutation_id': mutationId,
      'target_expected_recorded_hand_count': projectedRecordedHands.length,
      'target_expected_last_recorded_hand_id': expectedLastRecordedHandId,
    };

    await store.insertMutation(
      OfflineMutationRecord(
        id: mutationId,
        kind: OfflineMutationKind.recordFalseWinPenalty,
        eventId: cached.session.eventId,
        sessionId: input.tableSessionId,
        payload: payload,
        baseRecordedHandCount: projectedRecordedHands.length,
        baseLastRecordedHandId: expectedLastRecordedHandId,
        localHandNumber: projectedRecordedHands.length + 1,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );

    final projected = (await _project(cached)).detail;
    _scheduleSync();
    return projected;
  }

  void _scheduleSync() {
    final onMutationQueued = _onMutationQueued;
    if (onMutationQueued != null) {
      unawaited(onMutationQueued());
    }
  }

  List<HandResultRecord> _projectedRecordedHands(
    SessionDetailRecord cached,
    List<OfflineMutationRecord> existingMutations,
  ) {
    final currentProjection = projector
        .project(
          detail: cached,
          mutations: existingMutations,
        )
        .detail;
    return _recordedHandsExcludingBlocked(currentProjection, existingMutations);
  }

  List<HandResultRecord> _recordedHandsExcludingBlocked(
    SessionDetailRecord currentProjection,
    List<OfflineMutationRecord> existingMutations,
  ) {
    final blockedPendingHandIds = existingMutations
        .where((mutation) => mutation.status == OfflineMutationStatus.blocked)
        .map((mutation) => 'pending:${mutation.id}')
        .toSet();
    return currentProjection.hands
        .where(
          (hand) =>
              hand.status == HandResultStatus.recorded &&
              !blockedPendingHandIds.contains(hand.id),
        )
        .toList(growable: false);
  }

  Future<ProjectedSessionDetail> _project(SessionDetailRecord detail) async {
    final mutations = await store.readMutationsForSession(detail.session.id);
    return projector.project(detail: detail, mutations: mutations);
  }

  SessionSyncSnapshot _snapshotFromMutations(
    String sessionId,
    List<OfflineMutationRecord> mutations,
  ) {
    final pendingHandIds = <String>{};
    final blockedHandIds = <String>{};
    String? blockedReason;

    for (final mutation in mutations) {
      switch (mutation.status) {
        case OfflineMutationStatus.pending:
        case OfflineMutationStatus.syncing:
        case OfflineMutationStatus.failed:
          pendingHandIds.add('pending:${mutation.id}');
        case OfflineMutationStatus.blocked:
          blockedHandIds.add('pending:${mutation.id}');
          blockedReason ??= mutation.lastError;
        case OfflineMutationStatus.synced:
          break;
      }
    }

    return SessionSyncSnapshot(
      sessionId: sessionId,
      pendingHandIds: pendingHandIds,
      blockedHandIds: blockedHandIds,
      pendingCount: pendingHandIds.length,
      isBlocked: blockedHandIds.isNotEmpty,
      blockedReason: blockedReason,
    );
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Pause timer is unavailable while offline.',
      );
    }
    return inner.pauseSession(sessionId);
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Resume timer is unavailable while offline.',
      );
    }
    return inner.resumeSession(sessionId);
  }

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Ending a session is unavailable while offline.',
      );
    }
    return inner.endSession(sessionId: sessionId, reason: reason);
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Editing hands is unavailable while offline.',
      );
    }
    return inner.editHand(input);
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Voiding hands is unavailable while offline.',
      );
    }
    return inner.voidHand(input);
  }

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Starting a session is unavailable while offline.',
      );
    }
    return inner.startAssignedSession(input);
  }

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) =>
      inner.readCachedSessions(eventId);

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) =>
      inner.listSessions(eventId);

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
          String eventId) =>
      inner.readCachedEventHandLedger(eventId);

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId) =>
      inner.loadEventHandLedger(eventId);

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Starting sessions is unavailable while offline.',
      );
    }
    return inner.startCurrentTournamentRoundSessions(eventId);
  }

  @override
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) async {
    if (!await reachability.isReachable()) {
      throw const OfflineUnsupportedOperationException(
        'Starting sessions is unavailable while offline.',
      );
    }
    return inner.startBonusAssignedTableSessions(
      eventId: eventId,
      bonusTableRole: bonusTableRole,
    );
  }
}
