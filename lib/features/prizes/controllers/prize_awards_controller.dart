import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class PrizeAwardsController extends ChangeNotifier {
  PrizeAwardsController({
    required this.eventId,
    required this.prizeRepository,
  });

  final String eventId;
  final PrizeRepository prizeRepository;

  bool isLoading = false;
  String? error;
  List<PrizeAwardRecord> awards = const [];

  Future<void> load() async {
    awards = await prizeRepository.readCachedPrizeAwards(eventId);
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      awards = await prizeRepository.loadPrizeAwards(eventId);
    } catch (err) {
      if (awards.isEmpty) {
        error = err.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
