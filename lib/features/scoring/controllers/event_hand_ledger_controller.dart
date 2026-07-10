import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/event_hand_ledger_view_models.dart';

class EventHandLedgerCorrectionTarget {
  const EventHandLedgerCorrectionTarget({
    required this.detail,
    required this.hand,
    required this.guestNamesById,
  });

  final SessionDetailRecord detail;
  final HandResultRecord hand;
  final Map<String, String> guestNamesById;
}

class EventHandLedgerController extends ChangeNotifier {
  EventHandLedgerController({required this.sessionRepository});

  final SessionRepository sessionRepository;

  bool isLoading = false;
  bool isLoadingCorrection = false;
  String? error;
  String? correctionError;
  List<EventHandLedgerRowViewModel> rows = const [];

  Future<void> load(String eventId, {bool silent = false}) async {
    final shouldShowLoading = !silent;
    final previousRows = rows;
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    correctionError = null;
    final cachedRows = buildEventHandLedgerViewModels(
      await sessionRepository.readCachedEventHandLedger(eventId),
    );
    if (cachedRows.isNotEmpty || rows.isEmpty) {
      rows = cachedRows;
    }
    notifyListeners();

    try {
      rows = buildEventHandLedgerViewModels(
        await sessionRepository.loadEventHandLedger(eventId),
      );
    } catch (err) {
      if (previousRows.isNotEmpty) {
        rows = previousRows;
      }
      if (rows.isEmpty) {
        error = err.toString();
      }
    } finally {
      if (shouldShowLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<EventHandLedgerCorrectionTarget?> loadCorrectionTarget(
    EventHandLedgerRowViewModel row,
  ) async {
    if (!row.isHandRow) {
      return null;
    }

    isLoadingCorrection = true;
    correctionError = null;
    notifyListeners();
    try {
      final detail = await sessionRepository.loadSessionDetail(row.sessionId);
      final hand = _findHand(detail, row.handId);
      if (hand == null) {
        correctionError =
            'Hand is no longer available. Refresh the ledger and try again.';
        return null;
      }

      return EventHandLedgerCorrectionTarget(
        detail: detail,
        hand: hand,
        guestNamesById: row.guestNamesById,
      );
    } catch (err) {
      correctionError = err.toString();
      return null;
    } finally {
      isLoadingCorrection = false;
      notifyListeners();
    }
  }
}

HandResultRecord? _findHand(SessionDetailRecord detail, String handId) {
  for (final hand in detail.hands) {
    if (hand.id == handId) {
      return hand;
    }
  }
  return null;
}
