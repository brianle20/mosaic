import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventListController extends ChangeNotifier {
  EventListController({
    required EventRepository eventRepository,
    MosaicAccessState? accessState,
  })  : _eventRepository = eventRepository,
        _accessState = accessState;

  final EventRepository _eventRepository;
  final MosaicAccessState? _accessState;
  bool _isDisposed = false;

  bool isLoading = true;
  String? error;
  List<EventRecord> events = const [];

  bool get canCreateEvents =>
      _accessState == null || _accessState.ownedEvents.isNotEmpty;

  MosaicAccessRole? roleForEvent(String eventId) {
    if (_accessState == null) {
      return MosaicAccessRole.owner;
    }
    return _accessState.roleForEvent(eventId);
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notifyIfActive();

    final cachedEvents = await _eventRepository.readCachedEvents();
    if (_isDisposed) {
      return;
    }
    if (cachedEvents.isNotEmpty) {
      events = _latestCreatedFirst(_filterAccessible(cachedEvents));
      isLoading = false;
      _notifyIfActive();
    }

    try {
      events = _latestCreatedFirst(
        _filterAccessible(await _eventRepository.listEvents()),
      );
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

  List<EventRecord> _latestCreatedFirst(List<EventRecord> records) {
    return List<EventRecord>.from(records)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  List<EventRecord> _filterAccessible(List<EventRecord> records) {
    final accessState = _accessState;
    if (accessState == null) {
      return records;
    }
    final eventIds =
        accessState.events.map((accessEvent) => accessEvent.eventId).toSet();
    return records
        .where((record) => eventIds.contains(record.id))
        .toList(growable: false);
  }
}
