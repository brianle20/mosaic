import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventDashboardController extends ChangeNotifier {
  EventDashboardController({
    required EventRepository eventRepository,
    required GuestRepository guestRepository,
  })  : _eventRepository = eventRepository,
        _guestRepository = guestRepository;

  final EventRepository _eventRepository;
  final GuestRepository _guestRepository;

  bool isLoading = true;
  bool isSubmittingLifecycle = false;
  String? error;
  String? lifecycleError;
  EventRecord? event;
  int guestCount = 0;

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.getEvent(eventId) ??
          (await _eventRepository.readCachedEvents())
              .where((record) => record.id == eventId)
              .firstOrNull;
      guestCount = (await _guestRepository.readCachedGuests(eventId)).length;
      final remoteGuests = await _guestRepository.listGuests(eventId);
      guestCount = remoteGuests.length;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> completeEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.completeEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> finalizeEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.finalizeEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  String _formatLifecycleError(Object exception) {
    final message = exception.toString();
    const statePrefix = 'Bad state: ';
    if (message.startsWith(statePrefix)) {
      return message.substring(statePrefix.length);
    }
    return message;
  }

  Future<void> startEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.startEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> setOperationalFlags({
    required bool checkinOpen,
    required bool scoringOpen,
  }) async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.setOperationalFlags(
        eventId: currentEvent.id,
        checkinOpen: checkinOpen,
        scoringOpen: scoringOpen,
      );
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }
}
