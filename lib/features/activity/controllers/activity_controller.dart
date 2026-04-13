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

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    entries = await _activityRepository.readCachedActivity(
      eventId,
      selectedCategory,
    );
    notifyListeners();

    try {
      entries =
          await _activityRepository.loadActivity(eventId, selectedCategory);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
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
