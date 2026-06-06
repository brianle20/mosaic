import 'package:meta/meta.dart';

enum EventStaffRole {
  eventScorer,
}

EventStaffRole eventStaffRoleFromJson(String value) {
  return switch (value) {
    'qualification_scorer' => EventStaffRole.eventScorer,
    'event_scorer' => EventStaffRole.eventScorer,
    _ => throw ArgumentError('Unknown event staff role: $value'),
  };
}

String eventStaffRoleToJson(EventStaffRole role) {
  return switch (role) {
    EventStaffRole.eventScorer => 'event_scorer',
  };
}

enum EventStaffStatus {
  active,
  disabled,
}

EventStaffStatus eventStaffStatusFromJson(String value) {
  return switch (value) {
    'active' => EventStaffStatus.active,
    'disabled' => EventStaffStatus.disabled,
    _ => throw ArgumentError('Unknown event staff status: $value'),
  };
}

String eventStaffStatusToJson(EventStaffStatus status) {
  return switch (status) {
    EventStaffStatus.active => 'active',
    EventStaffStatus.disabled => 'disabled',
  };
}

@immutable
class EventStaffMembershipRecord {
  const EventStaffMembershipRecord({
    required this.id,
    required this.eventId,
    required this.displayName,
    required this.phoneE164,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedIdentityId,
    this.userId,
    this.email,
  });

  factory EventStaffMembershipRecord.fromJson(Map<String, dynamic> json) {
    return EventStaffMembershipRecord(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      approvedIdentityId: json['approved_identity_id'] as String?,
      userId: json['user_id'] as String?,
      email: json['email'] as String?,
      displayName: json['display_name'] as String,
      phoneE164: json['phone_e164'] as String?,
      role: eventStaffRoleFromJson(json['role'] as String),
      status: eventStaffStatusFromJson(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String eventId;
  final String? approvedIdentityId;
  final String? userId;
  final String? email;
  final String displayName;
  final String? phoneE164;
  final EventStaffRole role;
  final EventStaffStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EventStaffMembershipRecord &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            eventId == other.eventId &&
            approvedIdentityId == other.approvedIdentityId &&
            userId == other.userId &&
            email == other.email &&
            displayName == other.displayName &&
            phoneE164 == other.phoneE164 &&
            role == other.role &&
            status == other.status &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      eventId,
      approvedIdentityId,
      userId,
      email,
      displayName,
      phoneE164,
      role,
      status,
      createdAt,
      updatedAt,
    );
  }
}

@immutable
class UpsertEventStaffMembershipInput {
  const UpsertEventStaffMembershipInput({
    required this.eventId,
    required this.displayName,
    required this.role,
    this.email,
    this.phoneE164,
  });

  final String eventId;
  final String? email;
  final String? phoneE164;
  final String displayName;
  final EventStaffRole role;
}
