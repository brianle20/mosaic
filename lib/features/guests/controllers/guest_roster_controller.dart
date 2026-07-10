import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';

class GuestRosterController extends ChangeNotifier {
  GuestRosterController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isLoading = true;
  String? error;
  List<EventGuestRecord> guests = const [];
  final Set<String> _submittingGuestIds = <String>{};
  final Set<String> _qualifyingCheckedInConsideredGuestIds = <String>{};
  bool _isQualifyingCheckedInConsidered = false;
  int _requestGeneration = 0;
  bool _isDisposed = false;

  bool get isQualifyingCheckedInConsidered => _isQualifyingCheckedInConsidered;

  Future<void> load(String eventId, {bool silent = false}) async {
    final generation = ++_requestGeneration;
    if (!silent) {
      isLoading = true;
    }
    error = null;
    if (!silent) {
      _notifyIfActive();
    }

    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    if (!_isCurrent(generation)) return;
    if (cachedGuests.isNotEmpty) {
      guests = cachedGuests;
      if (!silent) {
        isLoading = false;
      }
      _notifyIfActive();
    }

    try {
      final loadedGuests = await _guestRepository.listGuests(eventId);
      if (!_isCurrent(generation)) return;
      guests = loadedGuests;
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      if (guests.isEmpty) {
        error = userFacingError(exception, fallback: 'Unable to load guests.');
      }
    }

    isLoading = false;
    _notifyIfActive();
  }

  bool isSubmittingGuest(String guestId) =>
      _submittingGuestIds.contains(guestId) ||
      _qualifyingCheckedInConsideredGuestIds.contains(guestId);

  Future<bool> markPaid(String guestId) async {
    final guest = _guestById(guestId);
    await _runGuestAction(
      guestId,
      () => _guestRepository
          .updateGuest(
            UpdateGuestInput(
              id: guest.id,
              eventId: guest.eventId,
              displayName: guest.displayName,
              normalizedName: guest.normalizedName,
              publicDisplayName: guest.publicDisplayName,
              phoneE164: guest.phoneE164,
              emailLower: guest.emailLower,
              coverStatus: CoverStatus.paid,
              coverAmountCents: guest.coverAmountCents,
              isComped: false,
              note: guest.note,
            ),
          )
          .then(_mergeGuest),
    );
    return true;
  }

  Future<bool> markComped(String guestId) async {
    final guest = _guestById(guestId);
    await _runGuestAction(
      guestId,
      () => _guestRepository
          .updateGuest(
            UpdateGuestInput(
              id: guest.id,
              eventId: guest.eventId,
              displayName: guest.displayName,
              normalizedName: guest.normalizedName,
              publicDisplayName: guest.publicDisplayName,
              phoneE164: guest.phoneE164,
              emailLower: guest.emailLower,
              coverStatus: CoverStatus.comped,
              coverAmountCents: guest.coverAmountCents,
              isComped: true,
              note: guest.note,
            ),
          )
          .then(_mergeGuest),
    );
    return true;
  }

  Future<bool> updateTournamentStatus({
    required String guestId,
    required EventTournamentStatus status,
  }) async {
    await _runGuestAction(
      guestId,
      () async {
        final updated = await _guestRepository.updateEventGuestTournamentStatus(
          eventGuestId: guestId,
          status: status,
        );
        _mergeGuest(updated);
      },
    );
    return true;
  }

  Future<int> qualifyCheckedInConsidered({Set<String>? guestIds}) async {
    if (_isQualifyingCheckedInConsidered) {
      return 0;
    }

    final targets = guests
        .where(
          (guest) =>
              guest.isCheckedIn &&
              guest.tournamentStatus == EventTournamentStatus.qualifying &&
              (guestIds == null || guestIds.contains(guest.id)) &&
              !isSubmittingGuest(guest.id),
        )
        .toList(growable: false);

    if (targets.isEmpty) {
      return 0;
    }

    final targetIds = targets.map((guest) => guest.id).toSet();
    _isQualifyingCheckedInConsidered = true;
    _qualifyingCheckedInConsideredGuestIds.addAll(targetIds);
    _notifyIfActive();

    var promotedCount = 0;
    try {
      for (final guest in targets) {
        final updated = await _guestRepository.updateEventGuestTournamentStatus(
          eventGuestId: guest.id,
          status: EventTournamentStatus.qualified,
        );
        _mergeGuest(updated);
        promotedCount += 1;
      }
      return promotedCount;
    } finally {
      _qualifyingCheckedInConsideredGuestIds.removeAll(targetIds);
      _isQualifyingCheckedInConsidered = false;
      _notifyIfActive();
    }
  }

  Future<bool> removeGuest(String guestId) async {
    await _runGuestAction(
      guestId,
      () async {
        await _guestRepository.removeGuest(guestId);
        if (_isDisposed) return;
        guests = guests
            .where((guest) => guest.id != guestId)
            .toList(growable: false);
      },
    );
    return true;
  }

  Future<bool> checkIn(String guestId) {
    return checkInForPlayMode(
      guestId: guestId,
      status: _guestById(guestId).tournamentStatus,
    );
  }

  Future<bool> checkInForPlayMode({
    required String guestId,
    required EventTournamentStatus status,
  }) async {
    await _runGuestAction(guestId, () async {
      final checkedInDetail = await _guestRepository.checkInGuest(guestId);
      _mergeGuest(checkedInDetail.guest);

      final updated = await _guestRepository.updateEventGuestTournamentStatus(
        eventGuestId: guestId,
        status: status,
      );
      _mergeGuest(updated);
    });
    return true;
  }

  Future<bool> undoCheckIn(String guestId) async {
    await _runGuestAction(guestId, () async {
      final updated = await _guestRepository.undoGuestCheckIn(guestId);
      _mergeGuest(updated);
    });
    return true;
  }

  Future<bool> recordCoverEntry({
    required String guestId,
    required SubmitCoverEntryInput input,
  }) async {
    await _runGuestAction(
      guestId,
      () async {
        final detail = await _guestRepository.recordCoverEntry(
          guestId: guestId,
          amountCents: input.amountCents,
          method: input.method,
          transactionOn: input.transactionOn,
          note: input.note,
        );
        _mergeGuest(detail.guest);
      },
    );
    return true;
  }

  EventGuestRecord _guestById(String guestId) {
    return guests.firstWhere((guest) => guest.id == guestId);
  }

  Future<void> _runGuestAction(
    String guestId,
    Future<void> Function() action,
  ) async {
    _submittingGuestIds.add(guestId);
    _notifyIfActive();
    try {
      await action();
    } finally {
      _submittingGuestIds.remove(guestId);
      _notifyIfActive();
    }
  }

  void _mergeGuest(EventGuestRecord guest) {
    if (_isDisposed) return;
    guests = [
      ...guests.where((entry) => entry.id != guest.id),
      guest,
    ]..sort((left, right) => left.displayName.compareTo(right.displayName));
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _requestGeneration;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration += 1;
    super.dispose();
  }
}
