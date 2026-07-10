import 'package:flutter/foundation.dart';
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

  Future<void> load({
    required String eventId,
    required String guestId,
    bool silent = false,
  }) async {
    if (!silent) {
      isLoading = true;
    }
    error = null;
    if (!silent) {
      notifyListeners();
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
    if (cachedGuest != null) {
      detail = GuestDetailRecord(
        guest: cachedGuest,
        coverEntries: cachedCoverEntries,
      );
      notifyListeners();
    }

    try {
      detail = await _guestRepository.getGuestDetail(guestId) ?? detail;
      if (detail == null) {
        error = 'Guest not found.';
      }
    } catch (exception) {
      if (detail == null) {
        error = exception.toString();
      }
    }

    if (!silent) {
      isLoading = false;
    }
    notifyListeners();
  }

  Future<void> checkIn({required String guestId}) async {
    if (detail == null) {
      return;
    }

    final currentDetail = detail!;
    if (!currentDetail.guest.isCoverSettledForCheckIn) {
      actionError = 'Guests must be paid or comped before check-in.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await _guestRepository.checkInGuest(guestId);
      if (!currentDetail.guest.isCheckedIn) {
        final updatedGuest =
            await _guestRepository.updateEventGuestTournamentStatus(
          eventGuestId: guestId,
          status: currentDetail.guest.tournamentStatus,
        );
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
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> recordCoverEntry({
    required String guestId,
    required SubmitCoverEntryInput input,
  }) async {
    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await _guestRepository.recordCoverEntry(
        guestId: guestId,
        amountCents: input.amountCents,
        method: input.method,
        transactionOn: input.transactionOn,
        note: input.note,
      );
    } catch (exception) {
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required SubmitCoverEntryInput input,
  }) async {
    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await _guestRepository.updateCoverEntry(
        guestId: guestId,
        coverEntryId: coverEntryId,
        amountCents: input.amountCents,
        method: input.method,
        transactionOn: input.transactionOn,
        note: input.note,
      );
    } catch (exception) {
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  }) async {
    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await _guestRepository.deleteCoverEntry(
        guestId: guestId,
        coverEntryId: coverEntryId,
      );
    } catch (exception) {
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }
}
