import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

class StartSessionController extends ChangeNotifier {
  StartSessionController({
    required this.table,
    this.scoringPhase = EventScoringPhase.tournament,
    required GuestRepository guestRepository,
    required SeatingRepository seatingRepository,
    required SessionRepository sessionRepository,
    String? preverifiedTableTagUid,
    this.allowAssignedTableEntry = false,
  })  : _seatingRepository = seatingRepository,
        _sessionRepository = sessionRepository,
        state = preverifiedTableTagUid == null
            ? StartSessionScanState.initial()
            : StartSessionScanState.withTableTag(preverifiedTableTagUid);

  final EventTableRecord table;
  final EventScoringPhase scoringPhase;
  final bool allowAssignedTableEntry;
  final SeatingRepository _seatingRepository;
  final SessionRepository _sessionRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? actionError;
  StartSessionScanState state;
  Map<int, SeatingAssignmentRecord> expectedAssignmentsBySeatIndex = const {};

  bool get hasValidAssignedSeats =>
      expectedAssignmentsBySeatIndex.length >= 2 &&
      expectedAssignmentsBySeatIndex.length <= 4;

  bool get hasAssignedTableSeating =>
      hasValidAssignedSeats &&
      (state.tableTagUid != null || allowAssignedTableEntry);

  bool get isAssignedSeatingMissing =>
      !hasValidAssignedSeats;

  bool get canScanNextTag => !isAssignedSeatingMissing && !canConfirmStart;

  bool get canConfirmStart => hasAssignedTableSeating;

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final seatingAssignments =
          await _seatingRepository.loadAssignments(eventId);
      expectedAssignmentsBySeatIndex =
          _expectedAssignmentsForTable(seatingAssignments);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  String get currentPrompt {
    if (hasAssignedTableSeating) {
      return 'Review assigned seating';
    }

    if (isAssignedSeatingMissing) {
      return 'Assigned seating required';
    }

    return switch (state.currentStep) {
      StartSessionScanStep.scanTable => 'Scan Table Tag',
      StartSessionScanStep.review => 'Review Session',
    };
  }

  List<ResolvedSeat> get resolvedSeats {
    if (hasAssignedTableSeating) {
      return [
        for (final entry
            in expectedAssignmentsBySeatIndex.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key)))
          ResolvedSeat(
            seatLabel: seatWindForIndex(entry.key).name,
            guestName: entry.value.displayName,
          ),
      ];
    }

    return const [];
  }

  void recordTableScan(String normalizedUid) {
    actionError = null;
    state = state.withTableTag(normalizedUid);
    notifyListeners();
  }

  void recordScanError(Object exception) {
    actionError = _formatActionError(exception);
    notifyListeners();
  }

  Future<StartedTableSessionRecord?> confirmStart() async {
    if (!canConfirmStart) {
      return null;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      final started = await _sessionRepository.startAssignedSession(
        StartAssignedTableSessionInput(
          eventTableId: table.id,
          scannedTableUid: state.tableTagUid,
        ),
      );
      isSubmitting = false;
      notifyListeners();
      return started;
    } catch (exception) {
      actionError = _formatActionError(exception);
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  Map<int, SeatingAssignmentRecord> _expectedAssignmentsForTable(
    List<SeatingAssignmentRecord> assignments,
  ) {
    final tableAssignments = assignments
        .where(
          (assignment) =>
              assignment.eventTableId == table.id &&
              assignment.status == 'active',
        )
        .toList(growable: false);
    if (tableAssignments.length < 2 || tableAssignments.length > 4) {
      return const {};
    }

    final seatIndexes = {
      for (final assignment in tableAssignments) assignment.seatIndex,
    };
    if (seatIndexes.length != tableAssignments.length) {
      return const {};
    }
    for (var index = 0; index < tableAssignments.length; index++) {
      if (!seatIndexes.contains(index)) {
        return const {};
      }
    }

    return {
      for (final assignment in tableAssignments)
        assignment.seatIndex: assignment,
    };
  }

  String _formatActionError(Object exception) {
    final message = exception.toString();
    if (message
        .toLowerCase()
        .contains('scanned table tag does not match the selected table')) {
      return 'This tag is not bound to ${table.label}. Scan the '
          '${table.label} tag, or rebind this table tag from Tables.';
    }

    return message;
  }
}

class ResolvedSeat {
  const ResolvedSeat({
    required this.seatLabel,
    required this.guestName,
  });

  final String seatLabel;
  final String guestName;
}
