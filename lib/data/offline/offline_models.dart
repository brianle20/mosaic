import 'package:meta/meta.dart';

enum OfflineMutationKind { recordHand, recordFalseWinPenalty }

enum OfflineMutationStatus { pending, syncing, synced, failed, blocked }

enum OfflinePhotoUploadStatus { pending, uploading, uploaded, failed, blocked }

enum OfflineStoreChangeKind { mutation, photoUpload }

@immutable
class OfflineStoreChange {
  OfflineStoreChange({
    required this.sessionId,
    required Set<OfflineStoreChangeKind> kinds,
  }) : kinds = Set.unmodifiable(kinds);

  final String sessionId;
  final Set<OfflineStoreChangeKind> kinds;
}

String offlineMutationKindToJson(OfflineMutationKind kind) {
  return switch (kind) {
    OfflineMutationKind.recordHand => 'record_hand',
    OfflineMutationKind.recordFalseWinPenalty => 'record_false_win_penalty',
  };
}

OfflineMutationKind offlineMutationKindFromJson(String value) {
  return switch (value) {
    'record_hand' => OfflineMutationKind.recordHand,
    'record_false_win_penalty' => OfflineMutationKind.recordFalseWinPenalty,
    _ => throw FormatException('Unknown offline mutation kind: $value'),
  };
}

String offlineMutationStatusToJson(OfflineMutationStatus status) {
  return switch (status) {
    OfflineMutationStatus.pending => 'pending',
    OfflineMutationStatus.syncing => 'syncing',
    OfflineMutationStatus.synced => 'synced',
    OfflineMutationStatus.failed => 'failed',
    OfflineMutationStatus.blocked => 'blocked',
  };
}

OfflineMutationStatus offlineMutationStatusFromJson(String value) {
  return switch (value) {
    'pending' => OfflineMutationStatus.pending,
    'syncing' => OfflineMutationStatus.syncing,
    'synced' => OfflineMutationStatus.synced,
    'failed' => OfflineMutationStatus.failed,
    'blocked' => OfflineMutationStatus.blocked,
    _ => throw FormatException('Unknown offline mutation status: $value'),
  };
}

String offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus status) {
  return switch (status) {
    OfflinePhotoUploadStatus.pending => 'pending',
    OfflinePhotoUploadStatus.uploading => 'uploading',
    OfflinePhotoUploadStatus.uploaded => 'uploaded',
    OfflinePhotoUploadStatus.failed => 'failed',
    OfflinePhotoUploadStatus.blocked => 'blocked',
  };
}

OfflinePhotoUploadStatus offlinePhotoUploadStatusFromJson(String value) {
  return switch (value) {
    'pending' => OfflinePhotoUploadStatus.pending,
    'uploading' => OfflinePhotoUploadStatus.uploading,
    'uploaded' => OfflinePhotoUploadStatus.uploaded,
    'failed' => OfflinePhotoUploadStatus.failed,
    'blocked' => OfflinePhotoUploadStatus.blocked,
    _ => throw FormatException('Unknown offline photo upload status: $value'),
  };
}

@immutable
class OfflineMutationRecord {
  OfflineMutationRecord({
    required this.id,
    required this.kind,
    required this.eventId,
    required this.sessionId,
    required Map<String, dynamic> payload,
    required this.baseRecordedHandCount,
    required this.baseLastRecordedHandId,
    required this.localHandNumber,
    required this.createdAt,
    required this.updatedAt,
    this.status = OfflineMutationStatus.pending,
    this.attemptCount = 0,
    this.lastError,
    this.lastAttemptedAt,
  }) : payload = Map.unmodifiable(payload);

  final String id;
  final OfflineMutationKind kind;
  final String eventId;
  final String sessionId;
  final Map<String, dynamic> payload;
  final int baseRecordedHandCount;
  final String? baseLastRecordedHandId;
  final int localHandNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OfflineMutationStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime? lastAttemptedAt;

  OfflineMutationRecord copyWith({
    OfflineMutationStatus? status,
    int? attemptCount,
    String? lastError,
    DateTime? lastAttemptedAt,
    DateTime? updatedAt,
  }) {
    return OfflineMutationRecord(
      id: id,
      kind: kind,
      eventId: eventId,
      sessionId: sessionId,
      payload: payload,
      baseRecordedHandCount: baseRecordedHandCount,
      baseLastRecordedHandId: baseLastRecordedHandId,
      localHandNumber: localHandNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
    );
  }
}

@immutable
class OfflinePhotoUploadRecord {
  const OfflinePhotoUploadRecord({
    required this.id,
    required this.mutationId,
    required this.eventId,
    required this.sessionId,
    required this.clientPhotoId,
    required this.localPath,
    required this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
    this.status = OfflinePhotoUploadStatus.pending,
    this.remoteHandResultId,
    this.storagePath,
    this.attemptCount = 0,
    this.lastError,
    this.lastAttemptedAt,
  });

  final String id;
  final String mutationId;
  final String eventId;
  final String sessionId;
  final String clientPhotoId;
  final String localPath;
  final DateTime capturedAt;
  final OfflinePhotoUploadStatus status;
  final String? remoteHandResultId;
  final String? storagePath;
  final int attemptCount;
  final String? lastError;
  final DateTime? lastAttemptedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class SessionSyncSnapshot {
  SessionSyncSnapshot({
    required this.sessionId,
    Set<String> pendingHandIds = const {},
    Set<String> blockedHandIds = const {},
    this.pendingCount = 0,
    this.isBlocked = false,
    this.blockedReason,
  })  : pendingHandIds = Set.unmodifiable(pendingHandIds),
        blockedHandIds = Set.unmodifiable(blockedHandIds);

  final String sessionId;
  final Set<String> pendingHandIds;
  final Set<String> blockedHandIds;
  final int pendingCount;
  final bool isBlocked;
  final String? blockedReason;
}

class OfflineUnsupportedOperationException implements Exception {
  const OfflineUnsupportedOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineSyncConflictException implements Exception {
  const OfflineSyncConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}
