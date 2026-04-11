import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventListController extends ChangeNotifier {
  EventListController({required EventRepository eventRepository})
      : _eventRepository = eventRepository;

  final EventRepository _eventRepository;

  bool isLoading = true;
  String? error;
  List<EventRecord> events = const [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final cachedEvents = await _eventRepository.readCachedEvents();
    if (cachedEvents.isNotEmpty) {
      events = cachedEvents;
      isLoading = false;
      notifyListeners();
    }

    try {
      events = await _eventRepository.listEvents();
      error = null;
    } catch (exception) {
      if (events.isEmpty) {
        error = exception.toString();
      }
    }

    isLoading = false;
    notifyListeners();
  }
}
