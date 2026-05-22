import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class SeatingAssignmentController extends ChangeNotifier {
  SeatingAssignmentController({
    required SeatingRepository seatingRepository,
    required GuestRepository guestRepository,
  })  : _seatingRepository = seatingRepository,
        _guestRepository = guestRepository;

  final SeatingRepository _seatingRepository;
  final GuestRepository _guestRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  List<SeatingAssignmentRecord> assignments = const [];
  List<EventGuestRecord> eligibleGuests = const [];
  List<EventGuestRecord> unassignedGuests = const [];

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

    final cachedAssignments = await _seatingRepository.readCachedAssignments(
      eventId,
    );
    assignments = cachedAssignments;
    notifyListeners();

    try {
      final loadedAssignments = await _seatingRepository.loadAssignments(
        eventId,
      );
      final loadedEligibleGuests = await _loadEligibleGuests(eventId);
      assignments = loadedAssignments;
      eligibleGuests = loadedEligibleGuests;
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
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      assignments = await _seatingRepository.generateRandomAssignments(eventId);
      await _refreshEligibleGuests(eventId);
      error = null;
    } catch (exception) {
      error = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> clear(String eventId) async {
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      assignments = await _seatingRepository.clearAssignments(eventId);
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

  Future<List<EventGuestRecord>> _loadEligibleGuests(String eventId) async {
    final guests = await _guestRepository.listGuests(eventId);
    final assignmentsByGuestId =
        await _guestRepository.listActiveTagAssignments(eventId);

    return guests.where((guest) {
      final tagAssignment = assignmentsByGuestId[guest.id];
      return guest.isCheckedIn &&
          tagAssignment != null &&
          tagAssignment.isActive &&
          tagAssignment.tag.defaultTagType == NfcTagType.player &&
          tagAssignment.tag.status == NfcTagStatus.active;
    }).toList(growable: false)
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
  }

  void _updateUnassignedGuests() {
    if (assignments.isEmpty) {
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
