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
  String? error;
  EventRecord? event;
  int guestCount = 0;

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
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
}
