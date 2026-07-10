import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

const seatingChangeBlockedMessage =
    'End active or paused sessions before changing seating.';
const bonusSeatingRoleRequiredMessage =
    'Bonus seating must use one table role.';

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
            _filterAssignments(initialAssignments, bonusTableRoleFilter),
        _initialAssignmentsPending = initialAssignments.isNotEmpty;

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
  int _requestGeneration = 0;
  bool _isDisposed = false;
  bool _initialAssignmentsPending;

  bool get canChangeSeating => !hasLiveSessions;
  bool get canStartAllTables => !hasLiveSessions;
  String get startAllTablesLabel {
    if (_hasStandardMixedFinalsRoles) {
      return 'Start Finals Tables';
    }

    final roles = _bonusTableRoles;
    if (roles == null || roles.length != 1) {
      return 'Start All Tables';
    }

    return switch (roles.single) {
      BonusTableRole.tableOfChampions ||
      BonusTableRole.tableOfRedemption =>
        tableGroups.length == 1 ? 'Start Finals Table' : 'Start Finals Tables',
      BonusTableRole.tableOfChampionsSuddenDeath => 'Start Sudden Death',
      BonusTableRole.tableOfChampionsPlayIn => 'Start Play-In',
    };
  }

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

  Future<void> load(String eventId, {bool silent = false}) async {
    final generation = ++_requestGeneration;
    if (!silent) {
      isLoading = true;
    }
    error = null;

    final cachedAssignments = _filterAssignments(
      await _seatingRepository.readCachedAssignments(eventId),
      bonusTableRoleFilter,
    );
    if (!_isCurrent(generation)) return;
    if (assignments.isEmpty) {
      assignments = cachedAssignments;
    }
    _notifyIfActive();

    try {
      final loadedAssignments = _filterAssignments(
        await _seatingRepository.loadAssignments(eventId),
        bonusTableRoleFilter,
      );
      if (!_isCurrent(generation)) return;
      final loadedEligibleGuests = await _loadEligibleGuests(eventId);
      if (!_isCurrent(generation)) return;
      final loadedHasLiveSessions = await _loadHasLiveSessions(eventId);
      if (!_isCurrent(generation)) return;
      if (_initialAssignmentsPending && !silent && loadedAssignments.isEmpty) {
        _initialAssignmentsPending = false;
      } else {
        assignments = loadedAssignments;
      }
      eligibleGuests = loadedEligibleGuests;
      hasLiveSessions = loadedHasLiveSessions;
      _updateUnassignedGuests();
      error = null;
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      if (assignments.isEmpty) {
        error = userFacingError(exception, fallback: 'Unable to load seating.');
      }
    }

    if (_isCurrent(generation)) {
      isLoading = false;
      _notifyIfActive();
    }
  }

  Future<void> generate(String eventId) async {
    await _refreshLiveSessions(eventId);
    if (hasLiveSessions) {
      error = seatingChangeBlockedMessage;
      _notifyIfActive();
      return;
    }

    isSubmitting = true;
    error = null;
    _notifyIfActive();

    try {
      assignments = _filterAssignments(
        await _seatingRepository.generateRandomAssignments(eventId),
        bonusTableRoleFilter,
      );
      await _refreshEligibleGuests(eventId);
      error = null;
    } catch (exception) {
      error = userFacingError(exception);
    }

    isSubmitting = false;
    _notifyIfActive();
  }

  Future<void> clear(String eventId) async {
    await _refreshLiveSessions(eventId);
    if (hasLiveSessions) {
      error = seatingChangeBlockedMessage;
      _notifyIfActive();
      return;
    }

    isSubmitting = true;
    error = null;
    _notifyIfActive();

    try {
      assignments = _filterAssignments(
        await _seatingRepository.clearAssignments(eventId),
        bonusTableRoleFilter,
      );
      _updateUnassignedGuests();
      error = null;
    } catch (exception) {
      error = userFacingError(exception);
    }

    isSubmitting = false;
    _notifyIfActive();
  }

  Future<void> startAllTables(String eventId) async {
    if (isSubmitting) {
      return;
    }

    isSubmitting = true;
    error = null;
    _notifyIfActive();

    try {
      await _refreshLiveSessions(eventId);
      if (hasLiveSessions) {
        error = seatingChangeBlockedMessage;
        return;
      }

      if (!canStartAllTables) {
        return;
      }

      if (assignments.isEmpty) {
        assignments = _filterAssignments(
          await _seatingRepository.generateTournamentRound(eventId),
          bonusTableRoleFilter,
        );
        _updateUnassignedGuests();
      }

      if (_hasInvalidBonusTableRole) {
        error = bonusSeatingRoleRequiredMessage;
        return;
      }

      if (!_hasOnlyBonusAssignments) {
        await _sessionRepository.startCurrentTournamentRoundSessions(eventId);
      } else {
        final roles = _bonusTableRoles!;
        await _sessionRepository.startBonusAssignedTableSessions(
          eventId: eventId,
          bonusTableRole: roles.length == 1 ? roles.single : null,
        );
      }
      await _refreshLiveSessions(eventId);
      error = null;
    } catch (exception) {
      try {
        await _refreshLiveSessions(eventId);
      } catch (_) {
        // Preserve the start error if we cannot determine whether sessions began.
      }
      if (hasLiveSessions) {
        error = null;
      } else {
        error = userFacingError(exception);
      }
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
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

    return guests.where((guest) {
      return guest.isCheckedIn &&
          guest.tournamentStatus == EventTournamentStatus.qualified;
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

  bool get _hasOnlyBonusAssignments =>
      assignments.isNotEmpty &&
      assignments.every(
        (assignment) =>
            assignment.assignmentType == SeatingAssignmentType.bonus,
      );

  bool get _hasInvalidBonusTableRole {
    if (!_hasOnlyBonusAssignments) {
      return false;
    }

    final roles = _bonusTableRoles;
    return roles == null || (roles.length > 1 && !_hasStandardMixedFinalsRoles);
  }

  bool get _hasStandardMixedFinalsRoles {
    final roles = _bonusTableRoles;
    return roles != null &&
        roles.length == 2 &&
        roles.contains(BonusTableRole.tableOfChampions) &&
        roles.contains(BonusTableRole.tableOfRedemption);
  }

  Set<BonusTableRole>? get _bonusTableRoles {
    if (!_hasOnlyBonusAssignments) {
      return null;
    }

    final roles = <BonusTableRole>{};
    for (final assignment in assignments) {
      final role = assignment.bonusTableRole;
      if (role == null) {
        return null;
      }
      roles.add(role);
    }

    return roles;
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _requestGeneration;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration += 1;
    super.dispose();
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
