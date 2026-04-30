import 'package:flutter/foundation.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/event_hand_ledger_view_models.dart';

class EventHandLedgerController extends ChangeNotifier {
  EventHandLedgerController({required this.sessionRepository});

  final SessionRepository sessionRepository;

  bool isLoading = false;
  String? error;
  List<EventHandLedgerRowViewModel> rows = const [];

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    rows = buildEventHandLedgerViewModels(
      await sessionRepository.readCachedEventHandLedger(eventId),
    );
    notifyListeners();

    try {
      rows = buildEventHandLedgerViewModels(
        await sessionRepository.loadEventHandLedger(eventId),
      );
    } catch (err) {
      if (rows.isEmpty) {
        error = err.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
