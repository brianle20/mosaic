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

  Future<void> load(String eventId, {bool silent = false}) async {
    final shouldShowLoading = !silent;
    final previousEntries = entries;
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    final cachedEntries = await _activityRepository.readCachedActivity(
      eventId,
      selectedCategory,
    );
    if (cachedEntries.isNotEmpty || entries.isEmpty) {
      entries = cachedEntries;
    }
    notifyListeners();

    try {
      entries =
          await _activityRepository.loadActivity(eventId, selectedCategory);
    } catch (exception) {
      if (previousEntries.isNotEmpty) {
        entries = previousEntries;
      }
      if (entries.isEmpty) {
        error = exception.toString();
      }
    }

    if (shouldShowLoading) {
      isLoading = false;
    }
    notifyListeners();
  }

  Future<void> selectCategory(
    String eventId,
    EventActivityCategory category,
  ) async {
    selectedCategory = category;
    await load(eventId);
  }
}
