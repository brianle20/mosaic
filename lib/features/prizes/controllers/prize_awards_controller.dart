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

  Future<void> load({bool silent = false}) async {
    final shouldShowLoading = !silent;
    final previousAwards = awards;
    final cachedAwards = await prizeRepository.readCachedPrizeAwards(eventId);
    if (cachedAwards.isNotEmpty || awards.isEmpty) {
      awards = cachedAwards;
    }
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    notifyListeners();

    try {
      awards = await prizeRepository.loadPrizeAwards(eventId);
    } catch (err) {
      if (previousAwards.isNotEmpty) {
        awards = previousAwards;
      }
      if (awards.isEmpty) {
        error = err.toString();
      }
    } finally {
      if (shouldShowLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }
}
