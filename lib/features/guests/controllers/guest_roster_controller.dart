import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class GuestRosterController extends ChangeNotifier {
  GuestRosterController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isLoading = true;
  String? error;
  List<EventGuestRecord> guests = const [];

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    if (cachedGuests.isNotEmpty) {
      guests = cachedGuests;
      isLoading = false;
      notifyListeners();
    }

    try {
      guests = await _guestRepository.listGuests(eventId);
    } catch (exception) {
      if (guests.isEmpty) {
        error = exception.toString();
      }
    }

    isLoading = false;
    notifyListeners();
  }
}
