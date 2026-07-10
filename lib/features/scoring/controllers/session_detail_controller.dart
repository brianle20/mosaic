import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/session_sync_status.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class SessionDetailController extends ChangeNotifier {
  SessionDetailController({
    required this.guestRepository,
    required this.sessionRepository,
  });

  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;

  bool isLoading = false;
  bool isSubmittingOperation = false;
  String? error;
  String? actionError;
  SessionDetailRecord? detail;
  SessionSyncSnapshot? syncSnapshot;
  Map<String, String> guestNamesById = const {};

  String? _eventId;
  String? _sessionId;
  int _requestGeneration = 0;
  int _detailRefreshGeneration = 0;
  StreamSubscription<void>? _syncSubscription;
  bool _isRefreshingSync = false;
  bool _syncRefreshQueued = false;
  bool _isDisposed = false;

  Future<void> load({
    required String eventId,
    required String sessionId,
  }) async {
    final generation = ++_requestGeneration;
    _detailRefreshGeneration += 1;
    _isRefreshingSync = false;
    _syncRefreshQueued = false;
    final oldSubscription = _syncSubscription;
    _syncSubscription = null;
    if (oldSubscription != null) {
      try {
        await oldSubscription.cancel();
      } catch (_) {
        // A stale subscription must not prevent the new request from loading.
      }
      if (!_isCurrentRequest(generation)) {
        return;
      }
    }

    final isSameTarget = _eventId == eventId && _sessionId == sessionId;
    _eventId = eventId;
    _sessionId = sessionId;
    if (!isSameTarget) {
      detail = null;
      syncSnapshot = null;
      guestNamesById = const {};
    }

    isLoading = detail == null;
    error = null;
    actionError = null;
    notifyListeners();

    final cachedDetailFuture = _capture(
      () => sessionRepository.readCachedSessionDetail(sessionId),
    );
    final cachedGuestsFuture = _capture(
      () => guestRepository.readCachedGuests(eventId),
    );
    final provider = sessionRepository is SessionSyncStatusProvider
        ? sessionRepository as SessionSyncStatusProvider
        : null;
    final cachedSnapshotFuture = provider == null
        ? Future.value(const _LoadResult<SessionSyncSnapshot>(value: null))
        : _capture(() => provider.readSessionSyncSnapshot(sessionId));

    final cachedDetail = await cachedDetailFuture;
    if (!_isCurrentRequest(generation) || _eventId != eventId) {
      return;
    }
    final cachedGuests = await cachedGuestsFuture;
    if (!_isCurrentRequest(generation)) {
      return;
    }
    final cachedSnapshot = await cachedSnapshotFuture;
    if (!_isCurrentRequest(generation)) {
      return;
    }

    if (cachedDetail.error == null && cachedDetail.value != null) {
      detail = cachedDetail.value;
    }
    if (cachedGuests.error == null && cachedGuests.value != null) {
      guestNamesById = _guestNamesById(cachedGuests.value!);
    }
    if (cachedSnapshot.error == null && cachedSnapshot.value != null) {
      syncSnapshot = cachedSnapshot.value;
    }
    if (detail != null) {
      isLoading = false;
    }
    notifyListeners();

    _subscribeToSyncChanges(provider, sessionId, generation);
    // Reread after subscribing so a store update emitted during the initial
    // snapshot-to-subscription handoff cannot be missed.
    if (provider != null) {
      final postSubscribeSnapshot = await _capture(
        () => provider.readSessionSyncSnapshot(sessionId),
      );
      if (!_isCurrentRequest(generation)) {
        return;
      }
      if (postSubscribeSnapshot.error == null &&
          postSubscribeSnapshot.value != null) {
        syncSnapshot = postSubscribeSnapshot.value;
        notifyListeners();
      }
    }

    final remoteDetailFuture = _loadRemoteDetail(
      eventId: eventId,
      sessionId: sessionId,
      generation: generation,
      showLoading: false,
    );
    final remoteGuestsFuture = _capture(
      () => guestRepository.listGuests(eventId),
    );

    await remoteDetailFuture;
    if (!_isCurrentRequest(generation)) {
      return;
    }
    final remoteGuests = await remoteGuestsFuture;
    if (!_isCurrentRequest(generation)) {
      return;
    }
    if (remoteGuests.error == null && remoteGuests.value != null) {
      guestNamesById = _guestNamesById(remoteGuests.value!);
      notifyListeners();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAfterRecovery() async {
    final eventId = _eventId;
    final sessionId = _sessionId;
    if (eventId == null || sessionId == null || _isDisposed) {
      return;
    }

    final provider = sessionRepository is SessionSyncStatusProvider
        ? sessionRepository as SessionSyncStatusProvider
        : null;
    final oldSubscription = _syncSubscription;
    _syncSubscription = null;
    if (oldSubscription != null) {
      unawaited(oldSubscription.cancel());
    }

    _isRefreshingSync = false;
    _syncRefreshQueued = false;
    final generation = ++_requestGeneration;
    // Reattach before reading the snapshot so a store event emitted during the
    // handoff is observed by the current generation.
    _subscribeToSyncChanges(provider, sessionId, generation);
    final remoteGuestsFuture = _capture(
      () => guestRepository.listGuests(eventId),
    );
    await _loadRemoteDetail(
      eventId: eventId,
      sessionId: sessionId,
      generation: generation,
      showLoading: false,
    );

    if (_isCurrentRequest(generation)) {
      final remoteGuests = await remoteGuestsFuture;
      if (remoteGuests.error == null && remoteGuests.value != null) {
        guestNamesById = _guestNamesById(remoteGuests.value!);
        notifyListeners();
      }
    }

    if (_isCurrentRequest(generation)) {
      if (provider != null) {
        final snapshot = await _capture(
          () => provider.readSessionSyncSnapshot(sessionId),
        );
        if (_isCurrentRequest(generation) && snapshot.value != null) {
          syncSnapshot = snapshot.value;
          notifyListeners();
        }
      }
    }
  }

  Future<void> _loadRemoteDetail({
    required String eventId,
    required String sessionId,
    required int generation,
    required bool showLoading,
  }) async {
    if (!_isCurrentRequest(generation) || _eventId != eventId) {
      return;
    }
    final detailRefreshGeneration = ++_detailRefreshGeneration;
    if (showLoading) {
      isLoading = true;
      notifyListeners();
    }

    final remoteDetail = await _capture(
      () => sessionRepository.loadSessionDetail(sessionId),
    );
    if (!_isCurrentRequest(generation)) {
      return;
    }

    if (remoteDetail.error == null &&
        remoteDetail.value != null &&
        detailRefreshGeneration == _detailRefreshGeneration) {
      detail = remoteDetail.value;
      error = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    if (detail == null && remoteDetail.error != null) {
      error = userFacingError(
        remoteDetail.error!,
        fallback: 'Unable to load session details.',
      );
    }
    if (showLoading || detail == null) {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryBlockedPhotoUploads() async {
    final provider = sessionRepository is SessionSyncStatusProvider
        ? sessionRepository as SessionSyncStatusProvider
        : null;
    final sessionId = _sessionId;
    if (provider == null || sessionId == null || _isDisposed) {
      return;
    }
    final generation = _requestGeneration;
    actionError = null;
    notifyListeners();
    try {
      await provider.retryBlockedPhotoUploads(sessionId);
      if (!_isCurrentRequest(generation)) {
        return;
      }
    } catch (error) {
      if (!_isCurrentRequest(generation)) {
        return;
      }
      actionError = _formatActionError(error);
      notifyListeners();
    }
  }

  Future<void> pauseSession() async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.pauseSession(currentDetail.session.id);
    } catch (err) {
      actionError = _formatActionError(err);
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  Future<void> resumeSession() async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.resumeSession(currentDetail.session.id);
    } catch (err) {
      actionError = _formatActionError(err);
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  Future<bool> endSession(String reason) async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return false;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.endSession(
        sessionId: currentDetail.session.id,
        reason: reason,
      );
      return true;
    } catch (err) {
      actionError = _formatActionError(err);
      return false;
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  void _subscribeToSyncChanges(
    SessionSyncStatusProvider? provider,
    String sessionId,
    int generation,
  ) {
    if (provider == null || !_isCurrentRequest(generation)) {
      return;
    }

    try {
      _syncSubscription = provider.watchSessionSyncChanges(sessionId).listen(
            (_) => unawaited(_handleSyncChange(generation)),
          );
    } catch (_) {
      _syncSubscription = null;
    }
  }

  Future<void> _handleSyncChange(int generation) async {
    if (!_isCurrentRequest(generation)) {
      return;
    }
    if (_isRefreshingSync) {
      _syncRefreshQueued = true;
      return;
    }
    final provider = sessionRepository is SessionSyncStatusProvider
        ? sessionRepository as SessionSyncStatusProvider
        : null;
    final sessionId = _sessionId;
    if (provider == null || sessionId == null) {
      return;
    }

    _isRefreshingSync = true;
    try {
      SessionSyncSnapshot nextSnapshot;
      try {
        nextSnapshot = await provider.readSessionSyncSnapshot(sessionId);
      } catch (_) {
        return;
      }
      if (!_isCurrentRequest(generation)) {
        return;
      }

      final previousSnapshot = syncSnapshot;
      syncSnapshot = nextSnapshot;
      final shouldReloadDetail = _isTerminalSyncTransition(
        previousSnapshot,
        nextSnapshot,
      );

      if (shouldReloadDetail) {
        final detailRefreshGeneration = ++_detailRefreshGeneration;
        try {
          final refreshedDetail =
              await sessionRepository.loadSessionDetail(sessionId);
          if (!_isCurrentRequest(generation) ||
              detailRefreshGeneration != _detailRefreshGeneration) {
            return;
          }
          detail = refreshedDetail;
          isLoading = false;
        } catch (_) {
          // Keep the currently rendered detail when a quiet refresh is offline.
        }
      }

      if (_isCurrentRequest(generation)) {
        notifyListeners();
      }
    } finally {
      if (_isCurrentRequest(generation)) {
        _isRefreshingSync = false;
        if (_syncRefreshQueued) {
          _syncRefreshQueued = false;
          unawaited(_handleSyncChange(generation));
        }
      }
    }
  }

  bool _isTerminalSyncTransition(
    SessionSyncSnapshot? previous,
    SessionSyncSnapshot next,
  ) {
    if (previous == null) {
      return false;
    }

    return _setLost(previous.pendingHandIds, next.pendingHandIds) ||
        _setGained(previous.blockedHandIds, next.blockedHandIds) ||
        _setLost(
          previous.pendingPhotoClientIds,
          next.pendingPhotoClientIds,
        ) ||
        _setGained(
          previous.blockedPhotoClientIds,
          next.blockedPhotoClientIds,
        );
  }

  bool _setLost(Set<String> previous, Set<String> next) {
    return !setEquals(previous, next) &&
        previous.any((value) => !next.contains(value));
  }

  bool _setGained(Set<String> previous, Set<String> next) {
    return !setEquals(previous, next) &&
        next.any((value) => !previous.contains(value));
  }

  Map<String, String> _guestNamesById(List<EventGuestRecord> guests) {
    return {
      for (final guest in guests) guest.id: guest.displayName,
    };
  }

  bool _isCurrentRequest(int generation) {
    return generation == _requestGeneration && !_isDisposed;
  }

  String _formatActionError(Object exception) {
    return userFacingError(exception);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncRefreshQueued = false;
    _requestGeneration += 1;
    final subscription = _syncSubscription;
    _syncSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

class _LoadResult<T> {
  const _LoadResult({this.value, this.error});

  final T? value;
  final Object? error;
}

Future<_LoadResult<T>> _capture<T>(Future<T> Function() operation) async {
  try {
    return _LoadResult<T>(value: await operation());
  } catch (error) {
    return _LoadResult<T>(error: error);
  }
}
