import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventListController extends ChangeNotifier {
  EventListController({required EventRepository eventRepository})
      : _eventRepository = eventRepository;

  final EventRepository _eventRepository;
  bool _isDisposed = false;

  bool isLoading = true;
  String? error;
  List<EventRecord> events = const [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notifyIfActive();

    final cachedEvents = await _eventRepository.readCachedEvents();
    if (_isDisposed) {
      return;
    }
    if (cachedEvents.isNotEmpty) {
      events = cachedEvents;
      isLoading = false;
      _notifyIfActive();
    }

    try {
      events = await _eventRepository.listEvents();
      error = null;
    } catch (exception) {
      if (events.isEmpty) {
        error = exception.toString();
      }
    }

    if (_isDisposed) {
      return;
    }
    isLoading = false;
    _notifyIfActive();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
