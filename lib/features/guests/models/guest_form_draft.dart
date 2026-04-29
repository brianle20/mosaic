import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/guests/models/guest_contact_formatters.dart';

@immutable
class GuestFormDraft {
  const GuestFormDraft({
    required this.displayName,
    this.phoneE164 = '',
    this.email = '',
    this.instagramHandle = '',
    this.note = '',
    this.coverAmountCents = 0,
    this.coverStatus = CoverStatus.unpaid,
  });

  final String displayName;
  final String phoneE164;
  final String email;
  final String instagramHandle;
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

  String? get phoneError {
    if (phoneE164.trim().isEmpty) {
      return null;
    }

    return normalizeUsPhoneToE164(phoneE164) == null
        ? 'Enter a 10-digit phone number.'
        : null;
  }

  String? phoneE164Value() {
    return normalizeUsPhoneToE164(phoneE164);
  }

  String? emailLowerValue() {
    final trimmed = email.trim();
    return trimmed.isEmpty ? null : trimmed.toLowerCase();
  }

  String? get instagramHandleError {
    if (instagramHandle.trim().isEmpty) {
      return null;
    }

    return instagramHandleValue() == null
        ? 'Use letters, numbers, periods, or underscores, up to 30 characters.'
        : null;
  }

  String? instagramHandleValue() {
    return normalizeInstagramHandle(instagramHandle);
  }

  String normalizedDisplayName() {
    return displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  EventGuestRecord? duplicateNameMatch(
    Iterable<EventGuestRecord> existingGuests, {
    String? excludeGuestId,
  }) {
    final normalized = normalizedDisplayName();
    if (normalized.isEmpty) {
      return null;
    }

    for (final guest in existingGuests) {
      if (guest.id == excludeGuestId) {
        continue;
      }
      if (guest.normalizedName == normalized) {
        return guest;
      }
    }

    return null;
  }

  String? duplicateNameWarning(
    Iterable<EventGuestRecord> existingGuests, {
    String? excludeGuestId,
  }) {
    final duplicate = duplicateNameMatch(
      existingGuests,
      excludeGuestId: excludeGuestId,
    );
    if (duplicate == null) {
      return null;
    }

    return 'Another guest with this name already exists.';
  }

  bool get isValid =>
      displayNameError == null &&
      phoneError == null &&
      instagramHandleError == null &&
      coverAmountError == null;

  CreateGuestInput toCreateInput({required String eventId}) {
    final normalizedName = normalizedDisplayName();
    return CreateGuestInput(
      eventId: eventId,
      displayName: displayName.trim(),
      normalizedName: normalizedName,
      phoneE164: phoneE164Value(),
      emailLower: emailLowerValue(),
      instagramHandle: instagramHandleValue(),
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
      phoneE164: phoneE164Value(),
      emailLower: emailLowerValue(),
      instagramHandle: instagramHandleValue(),
      coverStatus: coverStatus,
      coverAmountCents: coverAmountCents,
      isComped: coverStatus == CoverStatus.comped,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }
}
