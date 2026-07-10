import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';

class GuestCheckInController extends ChangeNotifier {
  GuestCheckInController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? actionError;
  GuestDetailRecord? detail;
  int _requestGeneration = 0;
  bool _isDisposed = false;

  Future<void> load({
    required String eventId,
    required String guestId,
    bool silent = false,
  }) async {
    final generation = ++_requestGeneration;
    if (!silent) {
      isLoading = true;
    }
    error = null;
    if (!silent) {
      _notifyIfActive();
    }

    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    EventGuestRecord? cachedGuest;
    for (final guest in cachedGuests) {
      if (guest.id == guestId) {
        cachedGuest = guest;
        break;
      }
    }
    final cachedCoverEntries =
        await _guestRepository.readCachedGuestCoverEntries(guestId);
    if (!_isCurrent(generation)) return;
    if (cachedGuest != null) {
      detail = GuestDetailRecord(
        guest: cachedGuest,
        coverEntries: cachedCoverEntries,
      );
      if (!silent) isLoading = false;
      _notifyIfActive();
    }

    try {
      final loadedDetail = await _guestRepository.getGuestDetail(guestId);
      if (!_isCurrent(generation)) return;
      detail = loadedDetail;
      if (detail == null) {
        error = 'Guest not found.';
      }
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      if (detail == null) {
        error = userFacingError(exception, fallback: 'Unable to load guest details.');
      }
    }

    isLoading = false;
    _notifyIfActive();
  }

  Future<void> checkIn({required String guestId}) async {
    if (detail == null) {
      return;
    }

    final currentDetail = detail!;
    if (!currentDetail.guest.isCoverSettledForCheckIn) {
      actionError = 'Guests must be paid or comped before check-in.';
      _notifyIfActive();
      return;
    }

    isSubmitting = true;
    actionError = null;
    _notifyIfActive();

    try {
      detail = await _guestRepository.checkInGuest(guestId);
      if (_isDisposed) return;
      if (!currentDetail.guest.isCheckedIn) {
        final updatedGuest =
            await _guestRepository.updateEventGuestTournamentStatus(
          eventGuestId: guestId,
          status: currentDetail.guest.tournamentStatus,
        );
        if (_isDisposed) return;
        final checkedInDetail = detail;
        final coverEntries =
            checkedInDetail == null || checkedInDetail.coverEntries.isEmpty
                ? currentDetail.coverEntries
                : checkedInDetail.coverEntries;
        detail = GuestDetailRecord(
          guest: updatedGuest,
          coverEntries: coverEntries,
        );
      }
    } catch (exception) {
      if (!_isDisposed) {
        actionError = userFacingError(exception);
      }
    }

    isSubmitting = false;
    _notifyIfActive();
  }

  Future<void> recordCoverEntry({
    required String guestId,
    required SubmitCoverEntryInput input,
  }) async {
    isSubmitting = true;
    actionError = null;
    _notifyIfActive();

    try {
      final nextDetail = await _guestRepository.recordCoverEntry(
        guestId: guestId,
        amountCents: input.amountCents,
        method: input.method,
        transactionOn: input.transactionOn,
        note: input.note,
      );
      if (_isDisposed) return;
      detail = nextDetail;
    } catch (exception) {
      if (!_isDisposed) actionError = userFacingError(exception);
    }

    isSubmitting = false;
    _notifyIfActive();
  }

  Future<void> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required SubmitCoverEntryInput input,
  }) async {
    isSubmitting = true;
    actionError = null;
    _notifyIfActive();

    try {
      final nextDetail = await _guestRepository.updateCoverEntry(
        guestId: guestId,
        coverEntryId: coverEntryId,
        amountCents: input.amountCents,
        method: input.method,
        transactionOn: input.transactionOn,
        note: input.note,
      );
      if (_isDisposed) return;
      detail = nextDetail;
    } catch (exception) {
      if (!_isDisposed) actionError = userFacingError(exception);
    }

    isSubmitting = false;
    _notifyIfActive();
  }

  Future<void> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  }) async {
    isSubmitting = true;
    actionError = null;
    _notifyIfActive();

    try {
      final nextDetail = await _guestRepository.deleteCoverEntry(
        guestId: guestId,
        coverEntryId: coverEntryId,
      );
      if (_isDisposed) return;
      detail = nextDetail;
    } catch (exception) {
      if (!_isDisposed) actionError = userFacingError(exception);
    }

    isSubmitting = false;
    _notifyIfActive();
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
