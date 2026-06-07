import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
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
  })  : _guestRepository = guestRepository,
        _seatingRepository = seatingRepository,
        _sessionRepository = sessionRepository,
        state = preverifiedTableTagUid == null
            ? StartSessionScanState.initial()
            : StartSessionScanState.withTableTag(preverifiedTableTagUid);

  final EventTableRecord table;
  final EventScoringPhase scoringPhase;
  final bool allowAssignedTableEntry;
  final GuestRepository _guestRepository;
  final SeatingRepository _seatingRepository;
  final SessionRepository _sessionRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? actionError;
  StartSessionScanState state;
  Map<String, EventGuestRecord> guestsById = const {};
  Map<String, GuestTagAssignmentSummary> assignmentsByGuestId = const {};
  Map<int, SeatingAssignmentRecord> expectedAssignmentsBySeatIndex = const {};

  bool get hasValidAssignedSeats =>
      expectedAssignmentsBySeatIndex.length >= 2 &&
      expectedAssignmentsBySeatIndex.length <= 4;

  bool get hasAssignedTableSeating =>
      hasValidAssignedSeats &&
      (state.tableTagUid != null || allowAssignedTableEntry);

  bool get isAssignedSeatingMissing =>
      _shouldUseAssignedSeating && !hasValidAssignedSeats;

  bool get canScanNextTag => !isAssignedSeatingMissing && !canConfirmStart;

  bool get canConfirmStart =>
      hasAssignedTableSeating ||
      (!_shouldUseAssignedSeating && state.canReview);

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final guests = await _guestRepository.listGuests(eventId);
      final assignments =
          await _guestRepository.listActiveTagAssignments(eventId);
      final seatingAssignments =
          await _seatingRepository.loadAssignments(eventId);
      guestsById = {
        for (final guest in guests) guest.id: guest,
      };
      assignmentsByGuestId = assignments;
      expectedAssignmentsBySeatIndex = _shouldUseAssignedSeating
          ? _expectedAssignmentsForTable(seatingAssignments)
          : const {};
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

    final expectedAssignment = _expectedAssignmentForCurrentSeat;
    final currentSeatLabel = state.currentSeatLabel;
    if (expectedAssignment != null && currentSeatLabel != null) {
      return 'Scan ${expectedAssignment.displayName} for $currentSeatLabel';
    }

    return switch (state.currentStep) {
      StartSessionScanStep.scanTable => 'Scan Table Tag',
      StartSessionScanStep.scanEast => 'Scan East Player Tag',
      StartSessionScanStep.scanSouth => 'Scan South Player Tag',
      StartSessionScanStep.scanWest => 'Scan West Player Tag',
      StartSessionScanStep.scanNorth => 'Scan North Player Tag',
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

    final resolved = <ResolvedSeat>[];
    for (var index = 0; index < state.scannedPlayerUids.length; index++) {
      final assignment = _findAssignmentByUid(state.scannedPlayerUids[index]);
      if (assignment == null) {
        continue;
      }
      final guest = guestsById[assignment.eventGuestId];
      if (guest == null) {
        continue;
      }
      resolved.add(
        ResolvedSeat(
          seatLabel: seatWindForIndex(index).name,
          guestName: guest.displayName,
        ),
      );
    }
    return resolved;
  }

  void recordTableScan(String normalizedUid) {
    actionError = null;
    state = state.withTableTag(normalizedUid);
    notifyListeners();
  }

  void recordPlayerScan(String normalizedUid) {
    actionError = null;

    if (isAssignedSeatingMissing) {
      actionError = 'Generate seating assignments before entering this table.';
      notifyListeners();
      return;
    }

    final assignment = _findAssignmentByUid(normalizedUid);
    if (assignment == null) {
      actionError =
          'Unknown player tag. Register player tags during check-in first.';
      notifyListeners();
      return;
    }

    final expectedAssignment = _expectedAssignmentForCurrentSeat;
    if (expectedAssignment != null &&
        assignment.eventGuestId != expectedAssignment.eventGuestId) {
      actionError =
          'Expected ${expectedAssignment.displayName} for ${state.currentSeatLabel}. '
          'Scan the assigned player tag.';
      notifyListeners();
      return;
    }

    try {
      state = state.withPlayerTag(normalizedUid);
    } on StateError catch (exception) {
      actionError = exception.message;
    }
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
      final started = hasAssignedTableSeating
          ? await _sessionRepository.startAssignedSession(
              StartAssignedTableSessionInput(
                eventTableId: table.id,
                scannedTableUid: state.tableTagUid,
              ),
            )
          : await _sessionRepository.startSession(
              StartTableSessionInput(
                eventTableId: table.id,
                scannedTableUid: state.tableTagUid!,
                eastPlayerUid: state.scannedPlayerUids[0],
                southPlayerUid: state.scannedPlayerUids[1],
                westPlayerUid: state.scannedPlayerUids[2],
                northPlayerUid: state.scannedPlayerUids[3],
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

  GuestTagAssignmentSummary? _findAssignmentByUid(String normalizedUid) {
    for (final assignment in assignmentsByGuestId.values) {
      if (assignment.tag.uidHex == normalizedUid) {
        return assignment;
      }
    }
    return null;
  }

  SeatingAssignmentRecord? get _expectedAssignmentForCurrentSeat {
    final seatIndex = state.scannedPlayerUids.length;
    return expectedAssignmentsBySeatIndex[seatIndex];
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

  bool get _shouldUseAssignedSeating =>
      scoringPhase != EventScoringPhase.qualification;

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
