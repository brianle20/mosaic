import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
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
  int _requestGeneration = 0;
  bool _isDisposed = false;

  Future<void> load({bool silent = false}) async {
    final generation = ++_requestGeneration;
    final shouldShowLoading = !silent;
    final previousAwards = awards;
    final cachedAwards = await prizeRepository.readCachedPrizeAwards(eventId);
    if (!_isCurrent(generation)) return;
    if (cachedAwards.isNotEmpty || awards.isEmpty) {
      awards = cachedAwards;
    }
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    _notifyIfActive();

    try {
      final loadedAwards = await prizeRepository.loadPrizeAwards(eventId);
      if (!_isCurrent(generation)) return;
      awards = loadedAwards;
    } catch (err) {
      if (!_isCurrent(generation)) return;
      if (previousAwards.isNotEmpty) {
        awards = previousAwards;
      }
      if (awards.isEmpty) {
        error = userFacingError(err, fallback: 'Unable to load prize awards.');
      }
    } finally {
      if (_isCurrent(generation)) {
        isLoading = false;
        _notifyIfActive();
      }
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
