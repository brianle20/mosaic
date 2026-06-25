import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class BulkSavedGuestController extends ChangeNotifier {
  BulkSavedGuestController({
    required GuestRepository guestRepository,
    required this.eventId,
    required int eventCoverChargeCents,
    required List<EventGuestRecord> existingGuests,
  })  : _guestRepository = guestRepository,
        _coverAmountCents = eventCoverChargeCents {
    _alreadyAddedProfileIds.addAll(
      existingGuests.map((guest) => guest.guestProfileId),
    );
  }

  final GuestRepository _guestRepository;
  final String eventId;
  final Set<String> _alreadyAddedProfileIds = <String>{};
  final Set<String> _selectedProfileIds = <String>{};
  List<GuestProfileRecord> _profiles = const [];
  bool _isDisposed = false;
  int _loadRequestVersion = 0;
  String _searchQuery = '';

  List<GuestProfileRecord> get profiles => List.unmodifiable(_profiles);

  List<GuestProfileRecord> get filteredProfiles {
    final normalizedQuery = _normalizedSearchText(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return profiles;
    }

    return List.unmodifiable(
      _profiles.where(
        (profile) => _matchesProfileSearch(profile, normalizedQuery),
      ),
    );
  }

  EventTournamentStatus _tournamentStatus = EventTournamentStatus.qualified;
  CoverStatus _coverStatus = CoverStatus.unpaid;
  int _coverAmountCents;
  bool isLoading = false;
  bool _isSubmitting = false;
  String? error;

  bool get isSubmitting => _isSubmitting;

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

  EventTournamentStatus get tournamentStatus => _tournamentStatus;

  String get searchQuery => _searchQuery;

  set searchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    _notifyIfActive();
  }

  set tournamentStatus(EventTournamentStatus value) {
    if (_tournamentStatus == value) {
      return;
    }

    _tournamentStatus = value;
    _notifyIfActive();
  }

  CoverStatus get coverStatus => _coverStatus;

  set coverStatus(CoverStatus value) {
    if (_coverStatus == value) {
      return;
    }

    _coverStatus = value;
    _notifyIfActive();
  }

  int get coverAmountCents => _coverAmountCents;

  set coverAmountCents(int value) {
    final clampedValue = value < 0 ? 0 : value;
    if (_coverAmountCents == clampedValue) {
      return;
    }

    _coverAmountCents = clampedValue;
    _notifyIfActive();
  }

  int get selectedCount => _selectedProfileIds.length;

  Set<String> get selectedProfileIds => Set.unmodifiable(_selectedProfileIds);

  Future<void> loadProfiles() async {
    final requestVersion = ++_loadRequestVersion;
    isLoading = true;
    error = null;
    _notifyIfActive();

    try {
      final loadedProfiles = await _guestRepository.listGuestProfiles();
      if (!_shouldApplyLoadResult(requestVersion)) {
        return;
      }

      _profiles = loadedProfiles;
      _pruneSelectedProfileIds();
    } catch (exception) {
      if (!_shouldApplyLoadResult(requestVersion)) {
        return;
      }

      error = exception.toString();
    } finally {
      if (_isDisposed) {
        if (requestVersion == _loadRequestVersion) {
          isLoading = false;
        }
      } else if (requestVersion == _loadRequestVersion) {
        isLoading = false;
        _notifyIfActive();
      }
    }
  }

  bool isAlreadyAdded(String profileId) {
    return _alreadyAddedProfileIds.contains(profileId);
  }

  bool isSelected(String profileId) {
    return _selectedProfileIds.contains(profileId);
  }

  void toggleSelection(String profileId) {
    if (isAlreadyAdded(profileId)) {
      return;
    }

    if (!_selectedProfileIds.remove(profileId)) {
      _selectedProfileIds.add(profileId);
    }
    _notifyIfActive();
  }

  Future<BulkSavedGuestAddResult> addSelectedGuests() async {
    if (_isSubmitting) {
      return const BulkSavedGuestAddResult(addedCount: 0, failedCount: 0);
    }

    final selectedProfiles = _profiles
        .where((profile) => _selectedProfileIds.contains(profile.id))
        .toList(growable: false);
    if (selectedProfiles.isEmpty) {
      return const BulkSavedGuestAddResult(addedCount: 0, failedCount: 0);
    }

    _isSubmitting = true;
    _notifyIfActive();

    var addedCount = 0;
    var failedCount = 0;
    var changedSelection = false;

    try {
      for (final profile in selectedProfiles) {
        if (_isDisposed) {
          return BulkSavedGuestAddResult(
            addedCount: addedCount,
            failedCount: failedCount,
          );
        }

        try {
          await _guestRepository.createGuest(
            CreateGuestInput(
              eventId: eventId,
              guestProfileId: profile.id,
              displayName: profile.displayName,
              normalizedName: profile.normalizedName,
              publicDisplayName: profile.publicDisplayName,
              phoneE164: profile.phoneE164,
              emailLower: profile.emailLower,
              instagramHandle: profile.instagramHandle,
              tournamentStatus: _tournamentStatus,
              coverStatus: _coverStatus,
              coverAmountCents: _coverAmountCents,
              isComped: _coverStatus == CoverStatus.comped,
            ),
          );
          if (_isDisposed) {
            return BulkSavedGuestAddResult(
              addedCount: addedCount,
              failedCount: failedCount,
            );
          }

          addedCount += 1;
          _alreadyAddedProfileIds.add(profile.id);
          changedSelection =
              _selectedProfileIds.remove(profile.id) || changedSelection;
        } catch (_) {
          if (_isDisposed) {
            return BulkSavedGuestAddResult(
              addedCount: addedCount,
              failedCount: failedCount,
            );
          }

          failedCount += 1;
        }
      }

      return BulkSavedGuestAddResult(
        addedCount: addedCount,
        failedCount: failedCount,
      );
    } finally {
      _isSubmitting = false;
      if (!_isDisposed) {
        if (changedSelection || selectedProfiles.isNotEmpty) {
          _notifyIfActive();
        }
      }
    }
  }

  void _pruneSelectedProfileIds() {
    final selectableProfileIds = _profiles
        .map((profile) => profile.id)
        .where((profileId) => !isAlreadyAdded(profileId))
        .toSet();
    _selectedProfileIds.removeWhere(
      (profileId) => !selectableProfileIds.contains(profileId),
    );
  }

  bool _shouldApplyLoadResult(int requestVersion) {
    return !_isDisposed && requestVersion == _loadRequestVersion;
  }

  bool _matchesProfileSearch(
    GuestProfileRecord profile,
    String normalizedQuery,
  ) {
    final digitQuery = _digitsOnly(normalizedQuery);
    return _searchFieldsFor(profile).any(
      (field) {
        final normalizedField = _normalizedSearchText(field);
        return normalizedField.contains(normalizedQuery) ||
            (digitQuery.isNotEmpty &&
                _digitsOnly(normalizedField).contains(digitQuery));
      },
    );
  }

  Iterable<String> _searchFieldsFor(GuestProfileRecord profile) sync* {
    yield profile.displayName;
    yield profile.normalizedName;
    if (profile.publicDisplayName case final publicDisplayName?) {
      yield publicDisplayName;
    }
    if (profile.phoneE164 case final phoneE164?) {
      yield phoneE164;
      yield _digitsOnly(phoneE164);
    }
    if (profile.emailLower case final emailLower?) {
      yield emailLower;
    }
    if (profile.instagramHandle case final instagramHandle?) {
      yield instagramHandle;
      yield '@$instagramHandle';
    }
  }

  String _normalizedSearchText(String value) {
    return value.trim().toLowerCase();
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}

@immutable
class BulkSavedGuestAddResult {
  const BulkSavedGuestAddResult({
    required this.addedCount,
    required this.failedCount,
  });

  final int addedCount;
  final int failedCount;

  bool get hasFailures => failedCount > 0;

  bool get hasPartialSuccess => addedCount > 0 && failedCount > 0;

  bool get isCompleteFailure => addedCount == 0 && failedCount > 0;
}
