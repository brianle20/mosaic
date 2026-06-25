import 'package:meta/meta.dart';

enum HandPhotoUploadStatus {
  pending,
  uploaded,
  failed,
}

enum HandPhotoCaptureStatus {
  captured,
}

enum HandPhotoVisibility {
  hostAdminOnly,
}

enum HandTileValidationStatus {
  valid,
  invalid,
}

enum HandTileReviewStatus {
  unreviewed,
  matched,
  flagged,
  underDeclared,
  resolved,
}

@immutable
class HandPhotoRecord {
  const HandPhotoRecord({
    required this.id,
    required this.handResultId,
    required this.clientPhotoId,
    required this.capturedAt,
    required this.captureStatus,
    required this.uploadStatus,
    required this.visibility,
    this.capturedBy,
    this.localCapturePath,
    this.storageBucket,
    this.storagePath,
  });

  factory HandPhotoRecord.fromJson(Map<String, dynamic> json) {
    return HandPhotoRecord(
      id: _requiredString(json, 'id'),
      handResultId: _requiredString(json, 'hand_result_id'),
      clientPhotoId: _requiredString(json, 'client_photo_id'),
      capturedBy: _optionalString(json, 'captured_by'),
      capturedAt: _requiredDateTime(json, 'captured_at'),
      localCapturePath: _optionalString(json, 'local_capture_path'),
      storageBucket: _optionalString(json, 'storage_bucket'),
      storagePath: _optionalString(json, 'storage_path'),
      captureStatus: _photoCaptureStatusFromJson(
        _requiredString(json, 'photo_capture_status'),
      ),
      uploadStatus: _photoUploadStatusFromJson(
        _requiredString(json, 'photo_upload_status'),
      ),
      visibility: _photoVisibilityFromJson(
        _requiredString(json, 'visibility'),
      ),
    );
  }

  final String id;
  final String handResultId;
  final String clientPhotoId;
  final String? capturedBy;
  final DateTime capturedAt;
  final String? localCapturePath;
  final String? storageBucket;
  final String? storagePath;
  final HandPhotoCaptureStatus captureStatus;
  final HandPhotoUploadStatus uploadStatus;
  final HandPhotoVisibility visibility;
}

@immutable
class HandTileEntryRecord {
  const HandTileEntryRecord({
    required this.id,
    required this.handResultId,
    required this.enteredAt,
    required this.tilesJson,
    required this.calculationVersion,
    required this.validationStatus,
    required this.reviewStatus,
    this.enteredBy,
    this.calculatedFanCount,
    this.declaredFanCount,
    this.fanDelta,
  });

  factory HandTileEntryRecord.fromJson(Map<String, dynamic> json) {
    return HandTileEntryRecord(
      id: _requiredString(json, 'id'),
      handResultId: _requiredString(json, 'hand_result_id'),
      enteredBy: _optionalString(json, 'entered_by'),
      enteredAt: _requiredDateTime(json, 'entered_at'),
      tilesJson: _jsonValue(json, 'tiles_json'),
      calculatedFanCount: _optionalInt(json, 'calculated_fan_count'),
      declaredFanCount: _optionalInt(json, 'declared_fan_count'),
      fanDelta: _optionalInt(json, 'fan_delta'),
      calculationVersion: _requiredString(json, 'calculation_version'),
      validationStatus: _tileValidationStatusFromJson(
        _requiredString(json, 'validation_status'),
      ),
      reviewStatus: _tileReviewStatusFromJson(
        _requiredString(json, 'review_status'),
      ),
    );
  }

  final String id;
  final String handResultId;
  final String? enteredBy;
  final DateTime enteredAt;
  final Object tilesJson;
  final int? calculatedFanCount;
  final int? declaredFanCount;
  final int? fanDelta;
  final String calculationVersion;
  final HandTileValidationStatus validationStatus;
  final HandTileReviewStatus reviewStatus;
}

@immutable
class HandEvidenceReviewRecord {
  const HandEvidenceReviewRecord({
    required this.photo,
    required this.handResultId,
    this.handNumber,
    this.tableLabel,
    this.winnerName,
    this.winType,
    this.declaredFanCount,
    this.seatWindTileId,
    this.roundWindTileId,
    this.tileEntry,
  });

  factory HandEvidenceReviewRecord.fromJson(Map<String, dynamic> json) {
    final photoId =
        _optionalString(json, 'photo_id') ?? _requiredString(json, 'id');
    final tileEntryId = _optionalString(json, 'tile_entry_id');

    return HandEvidenceReviewRecord(
      photo: HandPhotoRecord.fromJson({
        ...json,
        'id': photoId,
      }),
      handResultId: _requiredString(json, 'hand_result_id'),
      handNumber: _optionalInt(json, 'hand_number'),
      tableLabel: _optionalString(json, 'table_label'),
      winnerName: _optionalString(json, 'winner_name'),
      winType: _optionalString(json, 'win_type'),
      declaredFanCount: _optionalInt(json, 'declared_fan_count'),
      seatWindTileId: _optionalString(json, 'seat_wind_tile_id'),
      roundWindTileId: _optionalString(json, 'round_wind_tile_id'),
      tileEntry: tileEntryId == null
          ? null
          : HandTileEntryRecord.fromJson({
              ...json,
              'id': tileEntryId,
            }),
    );
  }

  final HandPhotoRecord photo;
  final String handResultId;
  final int? handNumber;
  final String? tableLabel;
  final String? winnerName;
  final String? winType;
  final int? declaredFanCount;
  final String? seatWindTileId;
  final String? roundWindTileId;
  final HandTileEntryRecord? tileEntry;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Expected non-empty string for $key.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw FormatException('Expected string or null for $key.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
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

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  return DateTime.parse(_requiredString(json, key));
}

Object _jsonValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }

  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.cast<String, dynamic>(),
    );
  }

  if (value is List) {
    return List<dynamic>.unmodifiable(value);
  }

  throw FormatException('Expected object or array for $key.');
}

HandPhotoCaptureStatus _photoCaptureStatusFromJson(String value) {
  return switch (value) {
    'captured' => HandPhotoCaptureStatus.captured,
    _ => throw FormatException('Unknown hand photo capture status: $value'),
  };
}

HandPhotoUploadStatus _photoUploadStatusFromJson(String value) {
  return switch (value) {
    'pending' => HandPhotoUploadStatus.pending,
    'uploaded' => HandPhotoUploadStatus.uploaded,
    'failed' => HandPhotoUploadStatus.failed,
    _ => throw FormatException('Unknown hand photo upload status: $value'),
  };
}

HandPhotoVisibility _photoVisibilityFromJson(String value) {
  return switch (value) {
    'host_admin_only' => HandPhotoVisibility.hostAdminOnly,
    _ => throw FormatException('Unknown hand photo visibility: $value'),
  };
}

HandTileValidationStatus _tileValidationStatusFromJson(String value) {
  return switch (value) {
    'valid' => HandTileValidationStatus.valid,
    'invalid' => HandTileValidationStatus.invalid,
    _ => throw FormatException('Unknown hand tile validation status: $value'),
  };
}

HandTileReviewStatus _tileReviewStatusFromJson(String value) {
  return switch (value) {
    'unreviewed' => HandTileReviewStatus.unreviewed,
    'matched' => HandTileReviewStatus.matched,
    'flagged' => HandTileReviewStatus.flagged,
    'under_declared' => HandTileReviewStatus.underDeclared,
    'resolved' => HandTileReviewStatus.resolved,
    _ => throw FormatException('Unknown hand tile review status: $value'),
  };
}
