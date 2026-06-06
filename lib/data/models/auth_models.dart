import 'package:meta/meta.dart';

enum MosaicAccessRole {
  owner,
  eventScorer,
}

MosaicAccessRole mosaicAccessRoleFromJson(String value) {
  return switch (value) {
    'owner' => MosaicAccessRole.owner,
    'qualification_scorer' => MosaicAccessRole.eventScorer,
    'event_scorer' => MosaicAccessRole.eventScorer,
    _ => throw ArgumentError('Unknown Mosaic access role: $value'),
  };
}

String mosaicAccessRoleToJson(MosaicAccessRole role) {
  return switch (role) {
    MosaicAccessRole.owner => 'owner',
    MosaicAccessRole.eventScorer => 'event_scorer',
  };
}

extension MosaicAccessRoleCapabilities on MosaicAccessRole {
  bool get canManageEvent => this == MosaicAccessRole.owner;

  bool get canManageStaff => this == MosaicAccessRole.owner;

  bool get canScoreQualification => canScoreTournament;

  bool get canScoreTournament =>
      this == MosaicAccessRole.owner || this == MosaicAccessRole.eventScorer;

  bool get canScoreBonus =>
      this == MosaicAccessRole.owner || this == MosaicAccessRole.eventScorer;

  bool get canViewAssignedEvent => this == MosaicAccessRole.eventScorer;
}

@immutable
class HostAuthUser {
  const HostAuthUser({
    required this.id,
    this.email,
    this.phoneE164,
  });

  final String id;
  final String? email;
  final String? phoneE164;

  String get displayLabel {
    final email = this.email;
    if (email != null && email.isNotEmpty) {
      return email;
    }

    final phone = phoneE164;
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    return 'Mosaic user';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HostAuthUser &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            email == other.email &&
            phoneE164 == other.phoneE164;
  }

  @override
  int get hashCode => Object.hash(id, email, phoneE164);
}

@immutable
class MosaicAccessEvent {
  const MosaicAccessEvent({
    required this.eventId,
    required this.title,
    required this.role,
  });

  factory MosaicAccessEvent.fromJson(Map<String, dynamic> json) {
    return MosaicAccessEvent(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      role: mosaicAccessRoleFromJson(json['role'] as String),
    );
  }

  final String eventId;
  final String title;
  final MosaicAccessRole role;

  bool get isOwner => role == MosaicAccessRole.owner;

  bool get isAssignedStaff => !isOwner;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MosaicAccessEvent &&
            runtimeType == other.runtimeType &&
            eventId == other.eventId &&
            title == other.title &&
            role == other.role;
  }

  @override
  int get hashCode => Object.hash(eventId, title, role);
}

@immutable
class MosaicAccessState {
  const MosaicAccessState({
    required this.userId,
    required this.isActive,
    required this.events,
  });

  factory MosaicAccessState.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? const [];
    return MosaicAccessState(
      userId: json['userId'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      events: eventsJson
          .map((event) => MosaicAccessEvent.fromJson(
                (event as Map).cast<String, dynamic>(),
              ))
          .toList(growable: false),
    );
  }

  factory MosaicAccessState.fromRpcResponse(
    Object? response, {
    String? userId,
  }) {
    if (response is Map<String, dynamic>) {
      return MosaicAccessState.fromJson(response);
    }

    if (response is Map) {
      return MosaicAccessState.fromJson(response.cast<String, dynamic>());
    }

    if (response is List) {
      final events = response.map((row) {
        final json = (row as Map).cast<String, dynamic>();
        return MosaicAccessEvent(
          eventId: json['event_id'] as String,
          title: json['event_title'] as String,
          role: mosaicAccessRoleFromJson(json['role'] as String),
        );
      }).toList(growable: false);
      return MosaicAccessState(
        userId: userId,
        isActive: events.isNotEmpty,
        events: events,
      );
    }

    throw StateError(
      'Expected Mosaic access rows or object but received '
      '${response.runtimeType}.',
    );
  }

  final String? userId;
  final bool isActive;
  final List<MosaicAccessEvent> events;

  bool get hasApprovedAccess => isActive && events.isNotEmpty;

  List<MosaicAccessEvent> get ownedEvents {
    return events.where((event) => event.isOwner).toList(growable: false);
  }

  List<MosaicAccessEvent> get assignedEvents {
    return events
        .where((event) => event.isAssignedStaff)
        .toList(growable: false);
  }

  MosaicAccessEvent? accessForEvent(String eventId) {
    for (final event in events) {
      if (event.eventId == eventId) {
        return event;
      }
    }
    return null;
  }

  MosaicAccessRole? roleForEvent(String eventId) {
    return accessForEvent(eventId)?.role;
  }

  bool canManageEvent(String eventId) {
    return roleForEvent(eventId)?.canManageEvent ?? false;
  }

  bool canManageStaff(String eventId) {
    return roleForEvent(eventId)?.canManageStaff ?? false;
  }

  bool canScoreQualification(String eventId) {
    return roleForEvent(eventId)?.canScoreQualification ?? false;
  }

  bool canScoreTournament(String eventId) {
    return roleForEvent(eventId)?.canScoreTournament ?? false;
  }

  bool canScoreBonus(String eventId) {
    return roleForEvent(eventId)?.canScoreBonus ?? false;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MosaicAccessState &&
            runtimeType == other.runtimeType &&
            userId == other.userId &&
            isActive == other.isActive &&
            _listEquals(events, other.events);
  }

  @override
  int get hashCode => Object.hash(userId, isActive, Object.hashAll(events));
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
