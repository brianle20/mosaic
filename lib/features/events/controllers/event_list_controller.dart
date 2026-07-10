import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
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
  int _requestGeneration = 0;

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

  Future<void> load({bool silent = false}) async {
    final generation = ++_requestGeneration;
    if (!silent) {
      isLoading = true;
    }
    error = null;
    if (!silent) {
      _notifyIfActive();
    }

    final cachedEvents = await _eventRepository.readCachedEvents();
    if (!_isCurrent(generation)) {
      return;
    }
    if (cachedEvents.isNotEmpty) {
      events = _latestCreatedFirst(_filterAccessible(cachedEvents));
      if (!silent) {
        isLoading = false;
      }
      _notifyIfActive();
    }

    try {
      final loadedEvents = await _eventRepository.listEvents();
      if (!_isCurrent(generation)) return;
      events = _latestCreatedFirst(_filterAccessible(loadedEvents));
      error = null;
    } catch (exception) {
      if (!_isCurrent(generation)) {
        return;
      }
      if (events.isEmpty) {
        error = userFacingError(exception, fallback: 'Unable to load events.');
      }
    }

    if (!_isCurrent(generation)) {
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

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _requestGeneration;

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
