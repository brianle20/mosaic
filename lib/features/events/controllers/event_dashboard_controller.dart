import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventDashboardController extends ChangeNotifier {
  EventDashboardController({
    required EventRepository eventRepository,
    required GuestRepository guestRepository,
    PrizeRepository? prizeRepository,
  })  : _eventRepository = eventRepository,
        _guestRepository = guestRepository,
        _prizeRepository = prizeRepository;

  final EventRepository _eventRepository;
  final GuestRepository _guestRepository;
  final PrizeRepository? _prizeRepository;

  bool isLoading = true;
  bool isSubmittingLifecycle = false;
  String? error;
  String? lifecycleError;
  EventRecord? event;
  int guestCount = 0;
  int? prizePoolCents;

  Future<void> load(String eventId) async {
    final cachedEvent = (await _eventRepository.readCachedEvents())
        .where((record) => record.id == eventId)
        .firstOrNull;
    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    final cachedPrizePlan = await _prizeRepository?.readCachedPrizePlan(
      eventId,
    );

    isLoading = true;
    error = null;
    lifecycleError = null;
    event = cachedEvent;
    guestCount = cachedGuests.length;
    prizePoolCents = _totalPrizeCents(cachedPrizePlan);
    notifyListeners();

    try {
      event = await _eventRepository.getEvent(eventId) ?? event;
    } catch (exception) {
      if (event == null) {
        error = exception.toString();
      }
    }

    try {
      final remoteGuests = await _guestRepository.listGuests(eventId);
      guestCount = remoteGuests.length;
    } catch (exception) {
      if (event == null && guestCount == 0) {
        error ??= exception.toString();
      }
    }

    try {
      prizePoolCents = _totalPrizeCents(
        await _prizeRepository?.loadPrizePlan(eventId: eventId),
      );
    } catch (_) {
      // Prize setup is a dashboard summary only; keep event loading usable.
    }

    isLoading = false;
    notifyListeners();
  }

  int? _totalPrizeCents(PrizePlanDetail? detail) {
    if (detail == null) {
      return null;
    }

    final total = detail.tiers.fold<int>(
      0,
      (sum, tier) =>
          sum + ((tier.fixedAmountCents ?? 0) > 0 ? tier.fixedAmountCents! : 0),
    );

    return total > 0 ? total : null;
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

  Future<void> cancelEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.cancelEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> revertToDraft() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.revertEventToDraft(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<bool> deleteEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return false;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      await _eventRepository.deleteEvent(currentEvent.id);
      event = null;
      isSubmittingLifecycle = false;
      notifyListeners();
      return true;
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return false;
    }
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
