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

  Future<void> markPaid(String awardId) async {
    final updated = await prizeRepository.markPrizeAwardPaid(
      awardId: awardId,
      paidMethod: 'cash',
    );
    awards = [
      ...awards.where((award) => award.id != awardId),
      updated,
    ];
    awards.sort((left, right) => left.rankStart.compareTo(right.rankStart));
    notifyListeners();
  }

  Future<void> voidAward(String awardId) async {
    final updated = await prizeRepository.voidPrizeAward(awardId: awardId);
    awards = [
      ...awards.where((award) => award.id != awardId),
      updated,
    ]..sort((left, right) => left.rankStart.compareTo(right.rankStart));
    notifyListeners();
  }
}
