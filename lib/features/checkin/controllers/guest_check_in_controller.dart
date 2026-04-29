import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class GuestCheckInController extends ChangeNotifier {
  GuestCheckInController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? actionError;
  GuestDetailRecord? detail;

  Future<void> load(String guestId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      detail = await _guestRepository.getGuestDetail(guestId);
      if (detail == null) {
        error = 'Guest not found.';
      }
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> checkInAndAssign({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
  }) async {
    if (detail == null) {
      return;
    }

    final currentDetail = detail!;
    if (!currentDetail.guest.isEligibleForPlayerTagAssignment) {
      actionError =
          'Guests must be paid or comped before receiving a player tag.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      if (!currentDetail.guest.isCheckedIn) {
        detail = await _guestRepository.checkInGuest(guestId);
      }

      await _scanAndAssign(
        guestId: guestId,
        scanForTag: scanForTag,
        replaceExistingAssignment: false,
      );
    } catch (exception) {
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> assignTag({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
  }) async {
    if (detail == null) {
      return;
    }

    final currentDetail = detail!;
    if (!currentDetail.guest.isEligibleForPlayerTagAssignment) {
      actionError =
          'Guests must be paid or comped before receiving a player tag.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      await _scanAndAssign(
        guestId: guestId,
        scanForTag: scanForTag,
        replaceExistingAssignment: false,
      );
    } catch (exception) {
      actionError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  Future<void> replaceTag({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
  }) async {
    if (detail == null) {
      return;
    }

    final currentDetail = detail!;
    if (!currentDetail.guest.isEligibleForPlayerTagAssignment) {
      actionError =
          'Guests must be paid or comped before receiving a player tag.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      await _scanAndAssign(
        guestId: guestId,
        scanForTag: scanForTag,
        replaceExistingAssignment: true,
      );
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

  Future<void> _scanAndAssign({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
    required bool replaceExistingAssignment,
  }) async {
    final scanResult = await scanForTag();
    if (scanResult == null) {
      return;
    }

    detail = replaceExistingAssignment
        ? await _guestRepository.replaceGuestTag(
            guestId: guestId,
            scannedUid: scanResult.normalizedUid,
          )
        : await _guestRepository.assignGuestTag(
            guestId: guestId,
            scannedUid: scanResult.normalizedUid,
          );
  }
}
