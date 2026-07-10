import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class ActivityController extends ChangeNotifier {
  ActivityController({required ActivityRepository activityRepository})
      : _activityRepository = activityRepository;

  final ActivityRepository _activityRepository;

  bool isLoading = true;
  String? error;
  EventActivityCategory selectedCategory = EventActivityCategory.all;
  List<EventActivityEntry> entries = const [];
  int _requestGeneration = 0;

  Future<void> load(String eventId, {bool silent = false}) async {
    final requestGeneration = ++_requestGeneration;
    final category = selectedCategory;
    final shouldShowLoading = !silent;
    final previousEntries = entries;
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    final cachedEntries = await _activityRepository.readCachedActivity(
      eventId,
      category,
    );
    if (!_isCurrentRequest(requestGeneration, category)) {
      return;
    }
    if (cachedEntries.isNotEmpty || entries.isEmpty) {
      entries = cachedEntries;
    }
    notifyListeners();

    try {
      final loadedEntries =
          await _activityRepository.loadActivity(eventId, category);
      if (_isCurrentRequest(requestGeneration, category)) {
        entries = loadedEntries;
      }
    } catch (exception) {
      if (!_isCurrentRequest(requestGeneration, category)) {
        return;
      }
      if (previousEntries.isNotEmpty) {
        entries = previousEntries;
      }
      if (entries.isEmpty) {
        error = exception.toString();
      }
    }

    if (shouldShowLoading && _isCurrentRequest(requestGeneration, category)) {
      isLoading = false;
    }
    if (_isCurrentRequest(requestGeneration, category)) {
      notifyListeners();
    }
  }

  Future<void> selectCategory(
    String eventId,
    EventActivityCategory category,
  ) async {
    if (selectedCategory == category) {
      return;
    }
    selectedCategory = category;
    entries = const [];
    error = null;
    notifyListeners();
    await load(eventId);
  }

  bool _isCurrentRequest(
    int requestGeneration,
    EventActivityCategory category,
  ) {
    return requestGeneration == _requestGeneration &&
        category == selectedCategory;
  }
}
