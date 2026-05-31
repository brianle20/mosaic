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
    final accessRole = _accessState.roleForEvent(eventId);
    if (accessRole != null) {
      return accessRole;
    }
    return _isOwnedByCurrentUser(eventId) ? MosaicAccessRole.owner : null;
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
    final unarchivedRecords =
        records.where((record) => !record.isArchived).toList(growable: false);
    final accessState = _accessState;
    if (accessState == null) {
      return unarchivedRecords;
    }
    final eventIds =
        accessState.events.map((accessEvent) => accessEvent.eventId).toSet();
    return unarchivedRecords
        .where(
          (record) =>
              eventIds.contains(record.id) ||
              record.ownerUserId == accessState.userId,
        )
        .toList(growable: false);
  }

  bool _isOwnedByCurrentUser(String eventId) {
    final userId = _accessState?.userId;
    if (userId == null) {
      return false;
    }
    return events.any(
      (event) => event.id == eventId && event.ownerUserId == userId,
    );
  }
}
