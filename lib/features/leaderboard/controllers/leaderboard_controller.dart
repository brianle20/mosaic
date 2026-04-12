import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({required this.leaderboardRepository});

  final LeaderboardRepository leaderboardRepository;

  bool isLoading = false;
  String? error;
  List<LeaderboardEntry> entries = const [];

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      entries = await leaderboardRepository.loadLeaderboard(eventId);
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
