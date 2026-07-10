import 'dart:async';

import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_recovery_lifecycle.dart';
import 'package:mosaic/data/offline/offline_recovery_signal.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/offline_store.dart';
import 'package:mosaic/data/offline/sync_retry_scheduler.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_hand_evidence_repository.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';
import 'package:mosaic/services/media/hand_photo_storage.dart';
import 'package:supabase/supabase.dart';

class _SyncPassResult {
  const _SyncPassResult({
    this.reachedBackend = false,
    this.madeProgress = false,
    this.retryableWorkRemains = false,
  });

  final bool reachedBackend;
  final bool madeProgress;
  final bool retryableWorkRemains;
}

class _PhotoSyncResult {
  const _PhotoSyncResult({
    this.madeProgress = false,
    this.retryableWorkRemains = false,
  });

  final bool madeProgress;
  final bool retryableWorkRemains;
}

class SyncCoordinator
    implements OfflineRecoverySignal, OfflineRecoveryLifecycle {
  SyncCoordinator({
    required OfflineStore store,
    required NetworkReachability reachability,
    required SessionRepository sessionRepository,
    HandEvidenceRepository? handEvidenceRepository,
    SyncRetryScheduler? retryScheduler,
    HandPhotoStorage? photoStorage,
    DateTime Function()? now,
  })  : _store = store,
        _reachability = reachability,
        _sessionRepository = sessionRepository,
        _handEvidenceRepository = handEvidenceRepository,
        _retryScheduler = retryScheduler ?? TimerSyncRetryScheduler(),
        _photoStorage = photoStorage ?? LocalHandPhotoStorage(),
        _now = now ?? DateTime.now {
    if (sessionRepository is OfflineSessionRepository) {
      throw ArgumentError.value(
        sessionRepository,
        'sessionRepository',
        'SyncCoordinator requires the canonical online SessionRepository.',
      );
    }
  }

  final OfflineStore _store;
  final NetworkReachability _reachability;
  final SessionRepository _sessionRepository;
  final HandEvidenceRepository? _handEvidenceRepository;
  final SyncRetryScheduler _retryScheduler;
  final HandPhotoStorage _photoStorage;
  final DateTime Function() _now;
  final StreamController<int> _generationController =
      StreamController<int>.broadcast(sync: true);

  StreamSubscription<void>? _reachabilitySubscription;
  StreamSubscription<OfflineStoreChange>? _storeSubscription;
  final Set<Future<void>> _storeChangeFutures = {};
  var _isSyncing = false;
  var _syncRequested = false;
  var _reachableWhileSyncing = false;
  var _isForeground = true;
  Future<void>? _initializeFuture;
  Future<void>? _activeSyncFuture;
  Future<void>? _disposeFuture;
  var _lifecycleReady = false;
  var _resumeRequested = false;
  var _isDisposed = false;
  var _generation = 0;
  var _retryDelayIndex = 0;
  Set<String> _knownPendingWorkIds = const {};

  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  static const _scoreTotalsUniqueConstraint =
      'event_score_totals_event_id_event_guest_id_key';

  @override
  int get generation => _generation;

  @override
  Stream<int> get generations => _generationController.stream;

  Future<void> initialize() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    final initialization = _initializeInternal();
    _initializeFuture = initialization;
    return initialization;
  }

  Future<void> _initializeInternal() async {
    _reachabilitySubscription = _reachability.onReachable.listen((_) {
      if (_isDisposed || !_isForeground || !_lifecycleReady) {
        return;
      }
      _resetRetryBackoff();
      if (_isSyncing) {
        _reachableWhileSyncing = true;
        _syncRequested = true;
        return;
      }
      unawaited(syncNow(trigger: OfflineRecoveryTrigger.reachable));
    });
    _storeSubscription = _store.changes.listen((_) {
      final handling = _handleStoreChange();
      _storeChangeFutures.add(handling);
      unawaited(
        handling.then<void>(
          (_) => _storeChangeFutures.remove(handling),
          onError: (Object error, StackTrace stackTrace) {
            _storeChangeFutures.remove(handling);
          },
        ),
      );
    });

    await _store.resetSyncingToPending();
    await _store.resetBlockedMutationsToPending(
      lastErrorContains: _scoreTotalsUniqueConstraint,
    );
    await _store.resetPhotoUploadsUploadingToPending();
    _lifecycleReady = true;
    await syncNow(trigger: OfflineRecoveryTrigger.startup);
    if (_resumeRequested && _isForeground && !_isDisposed) {
      _resumeRequested = false;
      await syncNow(trigger: OfflineRecoveryTrigger.resumed);
    } else {
      _resumeRequested = false;
    }
  }

  Future<void> _handleStoreChange() async {
    if (_isDisposed || !_lifecycleReady) {
      return;
    }
    final wasSyncing = _isSyncing;
    if (wasSyncing) {
      _syncRequested = true;
    }
    final knownPendingWorkIds = Set<String>.of(_knownPendingWorkIds);
    final pendingWorkIds = await _readPendingWorkIds();
    if (!_isForeground) {
      _resumeRequested = true;
      _knownPendingWorkIds = pendingWorkIds;
      return;
    }
    final hasNewWork =
        pendingWorkIds.difference(knownPendingWorkIds).isNotEmpty;
    if (hasNewWork) {
      _resetRetryBackoff();
    }
    if (wasSyncing) {
      if (!_isSyncing && hasNewWork && !_isDisposed) {
        unawaited(syncNow(trigger: OfflineRecoveryTrigger.queuedWork));
      }
      return;
    }
    if (hasNewWork) {
      unawaited(syncNow(trigger: OfflineRecoveryTrigger.queuedWork));
    }
  }

  @override
  void setForeground(bool foreground) {
    if (_isDisposed || _isForeground == foreground) {
      return;
    }
    _isForeground = foreground;
    if (!foreground) {
      _retryScheduler.cancel();
      return;
    }
    _resetRetryBackoff();
    if (!_lifecycleReady && _initializeFuture != null) {
      _resumeRequested = true;
      return;
    }
    unawaited(syncNow(trigger: OfflineRecoveryTrigger.resumed));
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    if (_isDisposed) {
      return Future<void>.value();
    }

    _isDisposed = true;
    final disposal = _disposeInternal();
    _disposeFuture = disposal;
    return disposal;
  }

  Future<void> _disposeInternal() async {
    _retryScheduler.cancel();
    await _reachabilitySubscription?.cancel();
    await _storeSubscription?.cancel();

    final initializeFuture = _initializeFuture;
    if (initializeFuture != null) {
      try {
        await initializeFuture;
      } on Object {
        // Disposal must still release the store after a failed startup pass.
      }
    }

    final activeSyncFuture = _activeSyncFuture;
    if (activeSyncFuture != null &&
        !identical(activeSyncFuture, initializeFuture)) {
      try {
        await activeSyncFuture;
      } on Object {
        // Disposal must still close streams after a failed sync pass.
      }
    }

    final storeChangeFutures = List<Future<void>>.of(_storeChangeFutures);
    for (final storeChangeFuture in storeChangeFutures) {
      try {
        await storeChangeFuture;
      } on Object {
        // Disposal must still close streams after a failed store callback.
      }
    }

    await _generationController.close();
  }

  Future<void> syncNow({
    OfflineRecoveryTrigger trigger = OfflineRecoveryTrigger.manual,
  }) async {
    if (_isDisposed) {
      return Future<void>.value();
    }
    if (!_isForeground && trigger == OfflineRecoveryTrigger.queuedWork) {
      _resumeRequested = true;
      return Future<void>.value();
    }
    if (_isSyncing) {
      _syncRequested = true;
      return Future<void>.value();
    }

    final operation = _syncNowInternal(trigger: trigger);
    _activeSyncFuture = operation;
    try {
      await operation;
    } finally {
      _clearActiveSync(operation);
    }
  }

  void _clearActiveSync(Future<void> operation) {
    if (identical(_activeSyncFuture, operation)) {
      _activeSyncFuture = null;
    }
  }

  Future<void> _syncNowInternal({
    required OfflineRecoveryTrigger trigger,
  }) async {
    if (_isDisposed) {
      return;
    }
    if (trigger != OfflineRecoveryTrigger.retry) {
      _resetRetryBackoff();
    }
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    var reachedBackend = false;
    var retryableWorkRemains = false;
    var reachableWhileSyncing = false;
    try {
      do {
        _syncRequested = false;
        final result = await _syncPass();
        reachedBackend = reachedBackend || result.reachedBackend;
        retryableWorkRemains = result.retryableWorkRemains;
        if (result.madeProgress) {
          _resetRetryBackoff();
        }
      } while (_syncRequested && !retryableWorkRemains && !_isDisposed);
    } finally {
      _isSyncing = false;
      reachableWhileSyncing = _reachableWhileSyncing;
      _reachableWhileSyncing = false;
    }

    if (_isDisposed) {
      return;
    }
    if (retryableWorkRemains) {
      if (reachableWhileSyncing && _isForeground) {
        unawaited(syncNow(trigger: OfflineRecoveryTrigger.reachable));
      } else {
        _scheduleRetry();
      }
    } else {
      _retryScheduler.cancel();
    }
    if (reachedBackend) {
      _generation += 1;
      if (!_generationController.isClosed) {
        _generationController.add(_generation);
      }
    }
  }

  Future<_SyncPassResult> _syncPass() async {
    final mutations = await _store.readPendingMutations();
    final pendingPhotoUploads = await _store.readPendingPhotoUploads();
    _knownPendingWorkIds = {
      ...mutations.map((mutation) => 'mutation:${mutation.id}'),
      ...pendingPhotoUploads.map((upload) => 'photo:${upload.id}'),
    };
    if (!await _reachability.isReachable()) {
      return _SyncPassResult(
        retryableWorkRemains: await _hasRetryableWork(),
      );
    }

    var madeProgress = false;
    for (final mutation in mutations) {
      await _store.markSyncing(mutation.id, attemptedAt: _now().toUtc());

      try {
        switch (mutation.kind) {
          case OfflineMutationKind.recordHand:
            final detail = await _sessionRepository.recordHand(
              _inputFor(mutation),
            );
            await _attachRemoteHandResultId(mutation, detail);
          case OfflineMutationKind.recordFalseWinPenalty:
            await _sessionRepository.recordFalseWinPenalty(
              _falseWinPenaltyInputFor(mutation),
            );
        }
        await _store.markSynced(mutation.id);
        madeProgress = true;
      } on OfflineSyncConflictException catch (error) {
        await _store.markSessionBlocked(mutation.sessionId, error.toString());
        return _SyncPassResult(
          reachedBackend: true,
          madeProgress: madeProgress,
        );
      } catch (error) {
        if (_isRetryableScoreTotalsRefreshConflict(error)) {
          await _store.markFailed(mutation.id, error.toString());
          return _SyncPassResult(
            reachedBackend: true,
            madeProgress: madeProgress,
            retryableWorkRemains: true,
          );
        }

        if (_reachability.isNetworkException(error)) {
          await _store.markFailed(mutation.id, error.toString());
          return _SyncPassResult(
            reachedBackend: true,
            madeProgress: madeProgress,
            retryableWorkRemains: true,
          );
        }

        await _store.markSessionBlocked(mutation.sessionId, error.toString());
        return _SyncPassResult(
          reachedBackend: true,
          madeProgress: madeProgress,
        );
      }
    }

    final photoResult = await _syncPendingPhotoUploads();
    return _SyncPassResult(
      reachedBackend: true,
      madeProgress: madeProgress || photoResult.madeProgress,
      retryableWorkRemains: photoResult.retryableWorkRemains,
    );
  }

  bool _isRetryableScoreTotalsRefreshConflict(Object error) {
    if (error is PostgrestException) {
      final text = [
        error.message,
        error.details,
      ].whereType<String>().join(' ');
      return error.code == '23505' &&
          text.contains(_scoreTotalsUniqueConstraint);
    }

    final text = error.toString();
    return text.contains('23505') &&
        text.contains(_scoreTotalsUniqueConstraint);
  }

  Future<void> _attachRemoteHandResultId(
    OfflineMutationRecord mutation,
    SessionDetailRecord detail,
  ) async {
    final remoteHandResultId = _remoteHandResultIdFor(mutation, detail);
    if (remoteHandResultId == null) {
      await _store.markPhotoUploadBlockedForMutation(
        mutation.id,
        'Winning hand saved, but its photo could not be linked.',
      );
      return;
    }

    await _store.attachRemoteHandResultToPhotoUpload(
      mutation.id,
      remoteHandResultId,
    );
  }

  String? _remoteHandResultIdFor(
    OfflineMutationRecord mutation,
    SessionDetailRecord detail,
  ) {
    for (final hand in detail.hands) {
      if (hand.clientMutationId == mutation.id) {
        return hand.id;
      }
    }
    return null;
  }

  Future<_PhotoSyncResult> _syncPendingPhotoUploads() async {
    final repository = _handEvidenceRepository;
    if (repository == null) {
      return const _PhotoSyncResult();
    }

    var madeProgress = false;
    final uploads = await _store.readPendingPhotoUploads();
    for (final upload in uploads) {
      final remoteHandResultId = upload.remoteHandResultId;
      if (remoteHandResultId == null) {
        continue;
      }

      try {
        if (!await _photoStorage.exists(upload.localPath)) {
          await _store.markPhotoUploadBlocked(
            upload.id,
            'Photo file is missing.',
          );
          continue;
        }
      } catch (_) {
        await _store.markPhotoUploadBlocked(
          upload.id,
          'Photo file is missing.',
        );
        continue;
      }

      await _store.markPhotoUploadUploading(
        upload.id,
        attemptedAt: _now().toUtc(),
      );
      try {
        await repository.uploadAndAttachHandPhoto(
          eventId: upload.eventId,
          handResultId: remoteHandResultId,
          clientPhotoId: upload.clientPhotoId,
          localPath: upload.localPath,
          capturedAt: upload.capturedAt,
        );
        await _store.markPhotoUploadUploaded(
          upload.id,
          storagePath: SupabaseHandEvidenceRepository.storagePathFor(
            eventId: upload.eventId,
            handResultId: remoteHandResultId,
            clientPhotoId: upload.clientPhotoId,
          ),
        );
        madeProgress = true;
        try {
          await _photoStorage.delete(upload.localPath);
        } catch (_) {
          // The remote upload is the source of truth; local cleanup is best
          // effort and must not turn a completed upload into a retry.
        }
      } catch (error) {
        if (_reachability.isNetworkException(error)) {
          await _store.markPhotoUploadFailed(upload.id, error.toString());
          return _PhotoSyncResult(
            madeProgress: madeProgress,
            retryableWorkRemains: true,
          );
        }

        await _store.markPhotoUploadBlocked(upload.id, error.toString());
        continue;
      }
    }
    return _PhotoSyncResult(madeProgress: madeProgress);
  }

  Future<bool> _hasRetryableWork() async {
    if ((await _store.readPendingMutations()).isNotEmpty) {
      return true;
    }
    if (_handEvidenceRepository == null) {
      return false;
    }
    return (await _store.readPendingPhotoUploads()).any(
      (upload) => upload.remoteHandResultId != null,
    );
  }

  Future<Set<String>> _readPendingWorkIds() async {
    final mutations = await _store.readPendingMutations();
    final uploads = await _store.readPendingPhotoUploads();
    return {
      ...mutations.map((mutation) => 'mutation:${mutation.id}'),
      ...uploads.map((upload) => 'photo:${upload.id}'),
    };
  }

  void _resetRetryBackoff() {
    _retryDelayIndex = 0;
    _retryScheduler.cancel();
  }

  void _scheduleRetry() {
    if (_isDisposed || !_isForeground) {
      return;
    }
    final delay = _retryDelays[_retryDelayIndex];
    if (_retryDelayIndex < _retryDelays.length - 1) {
      _retryDelayIndex += 1;
    }
    _retryScheduler.schedule(delay, () {
      if (_isDisposed || !_isForeground) {
        return;
      }
      unawaited(syncNow(trigger: OfflineRecoveryTrigger.retry));
    });
  }

  RecordHandResultInput _inputFor(OfflineMutationRecord mutation) {
    if (mutation.kind != OfflineMutationKind.recordHand) {
      throw StateError('Unsupported offline mutation kind: ${mutation.kind}.');
    }

    final payload = mutation.payload;
    return RecordHandResultInput(
      tableSessionId: _stringValue(
        payload,
        'target_table_session_id',
        fallback: mutation.sessionId,
      ),
      resultType: _resultType(_requiredString(payload, 'target_result_type')),
      winnerSeatIndex: _optionalInt(payload, 'target_winner_seat_index'),
      winType: _optionalWinType(payload, 'target_win_type'),
      discarderSeatIndex: _optionalInt(
        payload,
        'target_discarder_seat_index',
      ),
      penaltySeatIndex: _optionalInt(payload, 'target_penalty_seat_index'),
      fanCount: _optionalInt(payload, 'target_fan_count'),
      winBonuses: _optionalWinBonuses(payload, 'target_win_bonuses'),
      dealerWasWaitingAtDraw: _optionalBool(
        payload,
        'target_dealer_was_waiting_at_draw',
      ),
      correctionNote: _optionalString(payload, 'target_correction_note'),
      clientMutationId: mutation.id,
      expectedRecordedHandCount: mutation.baseRecordedHandCount,
      expectedLastRecordedHandId: mutation.baseLastRecordedHandId,
      photoClientId: _optionalString(payload, 'target_photo_client_id'),
      photoCapturedAt: _optionalDateTime(payload, 'target_photo_captured_at'),
    );
  }

  RecordFalseWinPenaltyInput _falseWinPenaltyInputFor(
    OfflineMutationRecord mutation,
  ) {
    if (mutation.kind != OfflineMutationKind.recordFalseWinPenalty) {
      throw StateError('Unsupported offline mutation kind: ${mutation.kind}.');
    }

    final payload = mutation.payload;
    return RecordFalseWinPenaltyInput(
      tableSessionId: _stringValue(
        payload,
        'target_table_session_id',
        fallback: mutation.sessionId,
      ),
      penaltySeatIndex: _optionalInt(payload, 'target_penalty_seat_index') ??
          (throw const FormatException('Expected false win penalty seat.')),
      correctionNote: _optionalString(payload, 'target_correction_note'),
      clientMutationId: mutation.id,
      expectedRecordedHandCount: mutation.baseRecordedHandCount,
      expectedLastRecordedHandId: mutation.baseLastRecordedHandId,
    );
  }

  String _requiredString(Map<String, dynamic> payload, String key) {
    return _stringValue(payload, key);
  }

  String _stringValue(
    Map<String, dynamic> payload,
    String key, {
    String? fallback,
  }) {
    final value = payload[key] ?? fallback;
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('Expected non-empty string for $key.');
  }

  String? _optionalString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }

    throw FormatException('Expected string or null for $key.');
  }

  int? _optionalInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }

    throw FormatException('Expected int or null for $key.');
  }

  bool? _optionalBool(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }

    throw FormatException('Expected bool or null for $key.');
  }

  List<HandWinBonus>? _optionalWinBonuses(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is! List) {
      throw FormatException('Expected list or null for $key.');
    }

    return handWinBonusesFromIds(
      value.map((entry) {
        if (entry is String) {
          return entry;
        }
        throw FormatException('Expected string win bonus id for $key.');
      }),
    );
  }

  DateTime? _optionalDateTime(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.parse(value);
    }

    throw FormatException('Expected ISO-8601 string or null for $key.');
  }

  HandResultType _resultType(String value) {
    return switch (value) {
      'win' => HandResultType.win,
      'washout' => HandResultType.washout,
      'false_win_penalty' => HandResultType.falseWinPenalty,
      _ => throw FormatException('Unknown hand result type: $value'),
    };
  }

  HandWinType? _optionalWinType(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Expected string or null for $key.');
    }

    return switch (value) {
      'discard' => HandWinType.discard,
      'self_draw' => HandWinType.selfDraw,
      _ => throw FormatException('Unknown hand win type: $value'),
    };
  }
}
