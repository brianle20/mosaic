import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class SeatingAssignmentController extends ChangeNotifier {
  SeatingAssignmentController(this._seatingRepository);

  final SeatingRepository _seatingRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  List<SeatingAssignmentRecord> assignments = const [];

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
      assignments = await _seatingRepository.loadAssignments(eventId);
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
      error = null;
    } catch (exception) {
      error = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
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
