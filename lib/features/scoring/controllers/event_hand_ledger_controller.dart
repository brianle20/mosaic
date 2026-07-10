import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
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
  int _requestGeneration = 0;
  bool _isDisposed = false;

  Future<void> load(String eventId, {bool silent = false}) async {
    final generation = ++_requestGeneration;
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
    if (!_isCurrent(generation)) return;
    if (cachedRows.isNotEmpty || rows.isEmpty) {
      rows = cachedRows;
    }
    _notifyIfActive();

    try {
      final loadedRows = await sessionRepository.loadEventHandLedger(eventId);
      if (!_isCurrent(generation)) return;
      rows = buildEventHandLedgerViewModels(loadedRows);
    } catch (err) {
      if (!_isCurrent(generation)) return;
      if (previousRows.isNotEmpty) {
        rows = previousRows;
      }
      if (rows.isEmpty) {
        error = userFacingError(err, fallback: 'Unable to load the event ledger.');
      }
    } finally {
      if (_isCurrent(generation)) {
        isLoading = false;
        _notifyIfActive();
      }
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
    _notifyIfActive();
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
      correctionError = userFacingError(err, fallback: 'Unable to load hand details.');
      return null;
    } finally {
      isLoadingCorrection = false;
      _notifyIfActive();
    }
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

HandResultRecord? _findHand(SessionDetailRecord detail, String handId) {
  for (final hand in detail.hands) {
    if (hand.id == handId) {
      return hand;
    }
  }
  return null;
}
