import 'package:meta/meta.dart';

enum MosaicSourceQuality {
  legacyStandings,
  mosaicHandLedger,
  photoEvidence,
  tileEnriched,
}

enum MosaicRatingProvisionalState {
  provisional,
  semiProvisional,
  established,
}

enum MosaicProfileConfidence {
  earlyRead,
  developingProfile,
  establishedProfile,
}

enum TileDerivedConfidence {
  none,
  partial,
  full,
}

@immutable
class RatingSnapshotRecord {
  const RatingSnapshotRecord({
    required this.id,
    required this.playerId,
    required this.ratingAfter,
    required this.ratingDelta,
    required this.provisionalState,
    required this.sourceQuality,
    required this.inputsVersion,
    required this.inputsJson,
    required this.createdAt,
    this.eventId,
    this.tableSessionId,
    this.calculationBatchId,
    this.ratingBefore,
  });

  factory RatingSnapshotRecord.fromJson(Map<String, dynamic> json) {
    return RatingSnapshotRecord(
      id: _requiredString(json, 'id'),
      playerId: _requiredString(json, 'player_id'),
      eventId: _optionalString(json, 'event_id'),
      tableSessionId: _optionalString(json, 'table_session_id'),
      calculationBatchId: _optionalString(json, 'calculation_batch_id'),
      ratingBefore: _optionalInt(json, 'rating_before'),
      ratingAfter: _requiredInt(json, 'rating_after'),
      ratingDelta: _requiredInt(json, 'rating_delta'),
      provisionalState: _provisionalStateFromJson(
        _requiredString(json, 'provisional_state'),
      ),
      sourceQuality: _sourceQualityFromJson(
        _requiredString(json, 'source_quality'),
      ),
      inputsVersion: _requiredString(json, 'inputs_version'),
      inputsJson: _jsonObject(json, 'inputs_json'),
      createdAt: _requiredDateTime(json, 'created_at'),
    );
  }

  final String id;
  final String playerId;
  final String? eventId;
  final String? tableSessionId;
  final String? calculationBatchId;
  final int? ratingBefore;
  final int ratingAfter;
  final int ratingDelta;
  final MosaicRatingProvisionalState provisionalState;
  final MosaicSourceQuality sourceQuality;
  final String inputsVersion;
  final Map<String, dynamic> inputsJson;
  final DateTime createdAt;
}

@immutable
class ProfileSnapshotRecord {
  const ProfileSnapshotRecord({
    required this.id,
    required this.playerId,
    required this.profileDimensionsJson,
    required this.confidence,
    required this.sourceQuality,
    required this.tileDerivedConfidence,
    required this.inputsVersion,
    required this.privateReviewJson,
    required this.createdAt,
    this.eventId,
    this.styleArchetype,
    this.generatedFromOfficialDataThrough,
    this.generatedFromTileDataThrough,
  });

  factory ProfileSnapshotRecord.fromJson(Map<String, dynamic> json) {
    return ProfileSnapshotRecord(
      id: _requiredString(json, 'id'),
      playerId: _requiredString(json, 'player_id'),
      eventId: _optionalString(json, 'event_id'),
      profileDimensionsJson: _jsonObject(json, 'profile_dimensions_json'),
      styleArchetype: _optionalString(json, 'style_archetype'),
      confidence: _profileConfidenceFromJson(
        _requiredString(json, 'confidence'),
      ),
      sourceQuality: _sourceQualityFromJson(
        _requiredString(json, 'source_quality'),
      ),
      tileDerivedConfidence: _tileDerivedConfidenceFromJson(
        _requiredString(json, 'tile_derived_confidence'),
      ),
      generatedFromOfficialDataThrough: _optionalDateTime(
        json,
        'generated_from_official_data_through',
      ),
      generatedFromTileDataThrough: _optionalDateTime(
        json,
        'generated_from_tile_data_through',
      ),
      inputsVersion: _requiredString(json, 'inputs_version'),
      privateReviewJson: _jsonObject(json, 'private_review_json'),
      createdAt: _requiredDateTime(json, 'created_at'),
    );
  }

  final String id;
  final String playerId;
  final String? eventId;
  final Map<String, dynamic> profileDimensionsJson;
  final String? styleArchetype;
  final MosaicProfileConfidence confidence;
  final MosaicSourceQuality sourceQuality;
  final TileDerivedConfidence tileDerivedConfidence;
  final DateTime? generatedFromOfficialDataThrough;
  final DateTime? generatedFromTileDataThrough;
  final String inputsVersion;
  final Map<String, dynamic> privateReviewJson;
  final DateTime createdAt;
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

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected int for $key.');
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

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 string or null for $key.');
}

Map<String, dynamic> _jsonObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }

  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.cast<String, dynamic>(),
    );
  }

  throw FormatException('Expected object for $key.');
}

MosaicSourceQuality _sourceQualityFromJson(String value) {
  return switch (value) {
    'legacy_standings' => MosaicSourceQuality.legacyStandings,
    'mosaic_hand_ledger' => MosaicSourceQuality.mosaicHandLedger,
    'photo_evidence' => MosaicSourceQuality.photoEvidence,
    'tile_enriched' => MosaicSourceQuality.tileEnriched,
    _ => throw FormatException('Unknown mosaic source quality: $value'),
  };
}

MosaicRatingProvisionalState _provisionalStateFromJson(String value) {
  return switch (value) {
    'provisional' => MosaicRatingProvisionalState.provisional,
    'semi_provisional' => MosaicRatingProvisionalState.semiProvisional,
    'established' => MosaicRatingProvisionalState.established,
    _ =>
      throw FormatException('Unknown mosaic rating provisional state: $value'),
  };
}

MosaicProfileConfidence _profileConfidenceFromJson(String value) {
  return switch (value) {
    'early_read' => MosaicProfileConfidence.earlyRead,
    'developing_profile' => MosaicProfileConfidence.developingProfile,
    'established_profile' => MosaicProfileConfidence.establishedProfile,
    _ => throw FormatException('Unknown mosaic profile confidence: $value'),
  };
}

TileDerivedConfidence _tileDerivedConfidenceFromJson(String value) {
  return switch (value) {
    'none' => TileDerivedConfidence.none,
    'partial' => TileDerivedConfidence.partial,
    'full' => TileDerivedConfidence.full,
    _ => throw FormatException('Unknown tile-derived confidence: $value'),
  };
}
