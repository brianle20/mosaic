import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

class StartSessionController extends ChangeNotifier {
  StartSessionController({
    required this.table,
    required GuestRepository guestRepository,
    required SessionRepository sessionRepository,
    String? preverifiedTableTagUid,
  })  : _guestRepository = guestRepository,
        _sessionRepository = sessionRepository,
        state = preverifiedTableTagUid == null
            ? StartSessionScanState.initial()
            : StartSessionScanState.withTableTag(preverifiedTableTagUid);

  final EventTableRecord table;
  final GuestRepository _guestRepository;
  final SessionRepository _sessionRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? actionError;
  StartSessionScanState state;
  Map<String, EventGuestRecord> guestsById = const {};
  Map<String, GuestTagAssignmentSummary> assignmentsByGuestId = const {};

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final guests = await _guestRepository.listGuests(eventId);
      final assignments =
          await _guestRepository.listActiveTagAssignments(eventId);
      guestsById = {
        for (final guest in guests) guest.id: guest,
      };
      assignmentsByGuestId = assignments;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  String get currentPrompt {
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

    final assignment = _findAssignmentByUid(normalizedUid);
    if (assignment == null) {
      actionError =
          'Unknown player tag. Register player tags during check-in first.';
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
    actionError = exception.toString();
    notifyListeners();
  }

  Future<StartedTableSessionRecord?> confirmStart() async {
    if (!state.canReview) {
      return null;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      final started = await _sessionRepository.startSession(
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
      actionError = exception.toString();
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
}

class ResolvedSeat {
  const ResolvedSeat({
    required this.seatLabel,
    required this.guestName,
  });

  final String seatLabel;
  final String guestName;
}
