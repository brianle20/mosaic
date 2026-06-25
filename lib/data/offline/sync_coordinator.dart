import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/offline_store.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_hand_evidence_repository.dart';

class SyncCoordinator {
  SyncCoordinator({
    required OfflineStore store,
    required NetworkReachability reachability,
    required SessionRepository sessionRepository,
    HandEvidenceRepository? handEvidenceRepository,
    DateTime Function()? now,
  })  : _store = store,
        _reachability = reachability,
        _sessionRepository = sessionRepository,
        _handEvidenceRepository = handEvidenceRepository,
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
  final DateTime Function() _now;
  var _isSyncing = false;
  var _syncRequested = false;

  Future<void> initialize() async {
    await _store.resetSyncingToPending();
    await _store.resetPhotoUploadsUploadingToPending();
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    try {
      var completedPass = true;
      do {
        _syncRequested = false;
        completedPass = await _syncPass();
      } while (completedPass && _syncRequested);
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncPass() async {
    if (!await _reachability.isReachable()) {
      return false;
    }

    final mutations = await _store.readPendingMutations();
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
      } on OfflineSyncConflictException catch (error) {
        await _store.markSessionBlocked(mutation.sessionId, error.toString());
        return false;
      } catch (error) {
        if (_reachability.isNetworkException(error)) {
          await _store.markFailed(mutation.id, error.toString());
          return false;
        }

        await _store.markSessionBlocked(mutation.sessionId, error.toString());
        return false;
      }
    }

    await _syncPendingPhotoUploads();
    return true;
  }

  Future<void> _attachRemoteHandResultId(
    OfflineMutationRecord mutation,
    SessionDetailRecord detail,
  ) async {
    final remoteHandResultId = _remoteHandResultIdFor(mutation, detail);
    if (remoteHandResultId == null) {
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

  Future<void> _syncPendingPhotoUploads() async {
    final repository = _handEvidenceRepository;
    if (repository == null) {
      return;
    }

    final uploads = await _store.readPendingPhotoUploads();
    for (final upload in uploads) {
      final remoteHandResultId = upload.remoteHandResultId;
      if (remoteHandResultId == null) {
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
      } catch (error) {
        if (_reachability.isNetworkException(error)) {
          await _store.markPhotoUploadFailed(upload.id, error.toString());
          return;
        }

        await _store.markPhotoUploadBlocked(upload.id, error.toString());
        return;
      }
    }
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
