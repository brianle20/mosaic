import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class GuestRosterController extends ChangeNotifier {
  GuestRosterController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isLoading = true;
  String? error;
  List<EventGuestRecord> guests = const [];
  Map<String, GuestTagAssignmentSummary> activeTagAssignments = const {};
  final Set<String> _submittingGuestIds = <String>{};

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    if (cachedGuests.isNotEmpty) {
      guests = cachedGuests;
      isLoading = false;
      notifyListeners();
    }

    try {
      guests = await _guestRepository.listGuests(eventId);
      activeTagAssignments =
          await _guestRepository.listActiveTagAssignments(eventId);
    } catch (exception) {
      if (guests.isEmpty) {
        error = exception.toString();
      }
    }

    isLoading = false;
    notifyListeners();
  }

  bool isSubmittingGuest(String guestId) =>
      _submittingGuestIds.contains(guestId);

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

  Future<bool> checkInAndAssign({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
  }) async {
    var didAssign = false;
    await _runGuestAction(guestId, () async {
      final checkedInDetail = await _guestRepository.checkInGuest(guestId);
      _mergeGuest(checkedInDetail.guest);

      final scanResult = await scanForTag();
      if (scanResult == null) {
        return;
      }

      final assignedDetail = await _guestRepository.assignGuestTag(
        guestId: guestId,
        scannedUid: scanResult.normalizedUid,
      );
      _mergeGuest(assignedDetail.guest);
      _mergeAssignment(guestId, assignedDetail.activeTagAssignment);
      didAssign = true;
    });
    return didAssign;
  }

  Future<bool> assignTag({
    required String guestId,
    required Future<TagScanResult?> Function() scanForTag,
  }) async {
    var didAssign = false;
    await _runGuestAction(guestId, () async {
      final scanResult = await scanForTag();
      if (scanResult == null) {
        return;
      }

      final assignedDetail = await _guestRepository.assignGuestTag(
        guestId: guestId,
        scannedUid: scanResult.normalizedUid,
      );
      _mergeGuest(assignedDetail.guest);
      _mergeAssignment(guestId, assignedDetail.activeTagAssignment);
      didAssign = true;
    });
    return didAssign;
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
        _mergeAssignment(guestId, detail.activeTagAssignment);
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
    notifyListeners();
    try {
      await action();
    } finally {
      _submittingGuestIds.remove(guestId);
      notifyListeners();
    }
  }

  void _mergeGuest(EventGuestRecord guest) {
    guests = [
      ...guests.where((entry) => entry.id != guest.id),
      guest,
    ]..sort((left, right) => left.displayName.compareTo(right.displayName));
  }

  void _mergeAssignment(
    String guestId,
    GuestTagAssignmentSummary? assignment,
  ) {
    final updated = Map<String, GuestTagAssignmentSummary>.from(
      activeTagAssignments,
    );
    if (assignment == null) {
      updated.remove(guestId);
    } else {
      updated[guestId] = assignment;
    }
    activeTagAssignments = updated;
  }
}
