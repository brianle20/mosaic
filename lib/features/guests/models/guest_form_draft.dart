import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_display_names.dart' as guest_names;
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/guests/models/guest_contact_formatters.dart';

@immutable
class GuestFormDraft {
  const GuestFormDraft({
    required this.displayName,
    this.publicDisplayName,
    this.isPublicDisplayNameManuallyEdited = false,
    this.phoneE164 = '',
    this.email = '',
    this.instagramHandle = '',
    this.note = '',
    this.coverAmountCents = 0,
    this.coverStatus = CoverStatus.unpaid,
    this.tournamentStatus = EventTournamentStatus.qualified,
  });

  final String displayName;
  final String? publicDisplayName;
  final bool isPublicDisplayNameManuallyEdited;
  final String phoneE164;
  final String email;
  final String instagramHandle;
  final String note;
  final int coverAmountCents;
  final CoverStatus coverStatus;
  final EventTournamentStatus tournamentStatus;

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

  static String defaultPublicDisplayNameFor(String fullName) {
    return guest_names.defaultPublicDisplayNameFor(fullName);
  }

  String resolvedPublicDisplayName() {
    return guest_names.resolvePublicDisplayName(
      fullName: displayName,
      publicDisplayName: publicDisplayName,
    );
  }

  GuestFormDraft withDisplayName(String value) {
    return GuestFormDraft(
      displayName: value,
      publicDisplayName: isPublicDisplayNameManuallyEdited
          ? publicDisplayName
          : defaultPublicDisplayNameFor(value),
      isPublicDisplayNameManuallyEdited: isPublicDisplayNameManuallyEdited,
      phoneE164: phoneE164,
      email: email,
      instagramHandle: instagramHandle,
      note: note,
      coverAmountCents: coverAmountCents,
      coverStatus: coverStatus,
      tournamentStatus: tournamentStatus,
    );
  }

  GuestFormDraft withPublicDisplayName(String value) {
    return GuestFormDraft(
      displayName: displayName,
      publicDisplayName: value,
      isPublicDisplayNameManuallyEdited: true,
      phoneE164: phoneE164,
      email: email,
      instagramHandle: instagramHandle,
      note: note,
      coverAmountCents: coverAmountCents,
      coverStatus: coverStatus,
      tournamentStatus: tournamentStatus,
    );
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

  CreateGuestInput toCreateInput({
    required String eventId,
    String? guestProfileId,
  }) {
    final normalizedName = normalizedDisplayName();
    return CreateGuestInput(
      eventId: eventId,
      displayName: displayName.trim(),
      normalizedName: normalizedName,
      publicDisplayName: resolvedPublicDisplayName(),
      phoneE164: phoneE164Value(),
      emailLower: emailLowerValue(),
      instagramHandle: instagramHandleValue(),
      guestProfileId: guestProfileId,
      tournamentStatus: tournamentStatus,
      coverStatus: coverStatus,
      coverAmountCents: coverAmountCents,
      isComped: coverStatus == CoverStatus.comped,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }

  UpdateGuestInput toUpdateInput({
    required String id,
    required String eventId,
    EventTournamentStatus? tournamentStatus,
  }) {
    final normalizedName = normalizedDisplayName();
    return UpdateGuestInput(
      id: id,
      eventId: eventId,
      displayName: displayName.trim(),
      normalizedName: normalizedName,
      publicDisplayName: resolvedPublicDisplayName(),
      phoneE164: phoneE164Value(),
      emailLower: emailLowerValue(),
      instagramHandle: instagramHandleValue(),
      tournamentStatus: tournamentStatus,
      coverStatus: coverStatus,
      coverAmountCents: coverAmountCents,
      isComped: coverStatus == CoverStatus.comped,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }
}
