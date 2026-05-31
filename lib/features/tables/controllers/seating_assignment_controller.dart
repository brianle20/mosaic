import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

const seatingChangeBlockedMessage =
    'End active or paused sessions before changing seating.';

class SeatingAssignmentController extends ChangeNotifier {
  SeatingAssignmentController({
    required SeatingRepository seatingRepository,
    required GuestRepository guestRepository,
    required SessionRepository sessionRepository,
    List<SeatingAssignmentRecord> initialAssignments = const [],
    this.bonusTableRoleFilter,
    this.showUnassignedGuests = true,
  })  : _seatingRepository = seatingRepository,
        _guestRepository = guestRepository,
        _sessionRepository = sessionRepository,
        assignments =
            _filterAssignments(initialAssignments, bonusTableRoleFilter);

  final SeatingRepository _seatingRepository;
  final GuestRepository _guestRepository;
  final SessionRepository _sessionRepository;
  final BonusTableRole? bonusTableRoleFilter;
  final bool showUnassignedGuests;

  bool isLoading = true;
  bool isSubmitting = false;
  bool hasLiveSessions = false;
  String? error;
  List<SeatingAssignmentRecord> assignments;
  List<EventGuestRecord> eligibleGuests = const [];
  List<EventGuestRecord> unassignedGuests = const [];

  bool get canChangeSeating => !hasLiveSessions;

  List<SeatingTableGroup> get tableGroups {
    final groups = <String, SeatingTableGroup>{};
    for (final assignment in assignments) {
      final group = groups.putIfAbsent(
        assignment.eventTableId,
        () => SeatingTableGroup(
          eventTableId: assignment.eventTableId,
          tableLabel: assignment.tableLabel,
          seats: [],
        ),
      );
      group.seats.add(assignment);
    }

    return [
      for (final group in groups.values)
        SeatingTableGroup(
          eventTableId: group.eventTableId,
          tableLabel: group.tableLabel,
          seats: [...group.seats]
            ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex)),
        ),
    ];
  }

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;

    final cachedAssignments = _filterAssignments(
      await _seatingRepository.readCachedAssignments(eventId),
      bonusTableRoleFilter,
    );
    if (assignments.isEmpty) {
      assignments = cachedAssignments;
    }
    notifyListeners();

    try {
      final loadedAssignments = _filterAssignments(
        await _seatingRepository.loadAssignments(eventId),
        bonusTableRoleFilter,
      );
      final loadedEligibleGuests = await _loadEligibleGuests(eventId);
      final loadedHasLiveSessions = await _loadHasLiveSessions(eventId);
      if (loadedAssignments.isNotEmpty || assignments.isEmpty) {
        assignments = loadedAssignments;
      }
      eligibleGuests = loadedEligibleGuests;
      hasLiveSessions = loadedHasLiveSessions;
      _updateUnassignedGuests();
      error = null;
    } catch (exception) {
      if (assignments.isEmpty) {
        error = exception.toString();
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> generate(String eventId) async {
    await _refreshLiveSessions(eventId);
    if (hasLiveSessions) {
      error = seatingChangeBlockedMessage;
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      assignments = _filterAssignments(
        await _seatingRepository.generateRandomAssignments(eventId),
        bonusTableRoleFilter,
      );
      await _refreshEligibleGuests(eventId);
      error = null;
    } catch (exception) {
      error = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> clear(String eventId) async {
    await _refreshLiveSessions(eventId);
    if (hasLiveSessions) {
      error = seatingChangeBlockedMessage;
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      assignments = _filterAssignments(
        await _seatingRepository.clearAssignments(eventId),
        bonusTableRoleFilter,
      );
      _updateUnassignedGuests();
      error = null;
    } catch (exception) {
      error = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> _refreshEligibleGuests(String eventId) async {
    eligibleGuests = await _loadEligibleGuests(eventId);
    _updateUnassignedGuests();
  }

  Future<void> _refreshLiveSessions(String eventId) async {
    hasLiveSessions = await _loadHasLiveSessions(eventId);
  }

  Future<List<EventGuestRecord>> _loadEligibleGuests(String eventId) async {
    final guests = await _guestRepository.listGuests(eventId);
    final assignmentsByGuestId =
        await _guestRepository.listActiveTagAssignments(eventId);

    return guests.where((guest) {
      final tagAssignment = assignmentsByGuestId[guest.id];
      return guest.isCheckedIn &&
          guest.tournamentStatus == EventTournamentStatus.qualified &&
          tagAssignment != null &&
          tagAssignment.isActive &&
          tagAssignment.tag.defaultTagType == NfcTagType.player &&
          tagAssignment.tag.status == NfcTagStatus.active;
    }).toList(growable: false)
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
  }

  void _updateUnassignedGuests() {
    if (!showUnassignedGuests || assignments.isEmpty) {
      unassignedGuests = const [];
      return;
    }

    final assignedGuestIds = {
      for (final assignment in assignments) assignment.eventGuestId,
    };
    unassignedGuests = eligibleGuests
        .where((guest) => !assignedGuestIds.contains(guest.id))
        .toList(growable: false);
  }

  Future<bool> _loadHasLiveSessions(String eventId) async {
    final sessions = await _sessionRepository.listSessions(eventId);
    return sessions.any(
      (session) =>
          session.status == SessionStatus.active ||
          session.status == SessionStatus.paused,
    );
  }
}

List<SeatingAssignmentRecord> _filterAssignments(
  List<SeatingAssignmentRecord> assignments,
  BonusTableRole? bonusTableRoleFilter,
) {
  if (bonusTableRoleFilter == null) {
    return assignments;
  }

  return assignments
      .where((assignment) => assignment.bonusTableRole == bonusTableRoleFilter)
      .toList(growable: false);
}

class SeatingTableGroup {
  SeatingTableGroup({
    required this.eventTableId,
    required this.tableLabel,
    required this.seats,
  });

  final String eventTableId;
  final String tableLabel;
  final List<SeatingAssignmentRecord> seats;
}
