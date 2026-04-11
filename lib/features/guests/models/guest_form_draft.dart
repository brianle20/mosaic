import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_models.dart';

@immutable
class GuestFormDraft {
  const GuestFormDraft({
    required this.displayName,
    this.phoneE164 = '',
    this.email = '',
    this.note = '',
    this.coverAmountCents = 0,
    this.coverStatus = CoverStatus.unpaid,
  });

  final String displayName;
  final String phoneE164;
  final String email;
  final String note;
  final int coverAmountCents;
  final CoverStatus coverStatus;

  String? get displayNameError {
    if (displayName.trim().isEmpty) {
      return 'Name is required.';
    }

    return null;
  }

  String? get coverAmountError {
    if (coverAmountCents < 0) {
      return 'Cover amount must be zero or more.';
    }

    return null;
  }

  String normalizedDisplayName() {
    return displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? duplicateNameWarning(Iterable<EventGuestRecord> existingGuests) {
    final normalized = normalizedDisplayName();
    if (normalized.isEmpty) {
      return null;
    }

    for (final guest in existingGuests) {
      if (guest.normalizedName == normalized) {
        return 'Another guest with this name already exists.';
      }
    }

    return null;
  }

  bool get isValid => displayNameError == null && coverAmountError == null;

  CreateGuestInput toCreateInput({required String eventId}) {
    final normalizedName = normalizedDisplayName();
    return CreateGuestInput(
      eventId: eventId,
      displayName: displayName.trim(),
      normalizedName: normalizedName,
      phoneE164: phoneE164.trim().isEmpty ? null : phoneE164.trim(),
      emailLower: email.trim().isEmpty ? null : email.trim().toLowerCase(),
      coverStatus: coverStatus,
      coverAmountCents: coverAmountCents,
      isComped: coverStatus == CoverStatus.comped,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }

  UpdateGuestInput toUpdateInput({
    required String id,
    required String eventId,
  }) {
    final normalizedName = normalizedDisplayName();
    return UpdateGuestInput(
      id: id,
      eventId: eventId,
      displayName: displayName.trim(),
      normalizedName: normalizedName,
      phoneE164: phoneE164.trim().isEmpty ? null : phoneE164.trim(),
      emailLower: email.trim().isEmpty ? null : email.trim().toLowerCase(),
      coverStatus: coverStatus,
      coverAmountCents: coverAmountCents,
      isComped: coverStatus == CoverStatus.comped,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }
}
