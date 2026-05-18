import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';

@immutable
class SubmitCoverEntryInput {
  const SubmitCoverEntryInput({
    required this.amountCents,
    required this.method,
    required this.transactionOn,
    this.note,
  });

  final int amountCents;
  final CoverEntryMethod method;
  final DateTime transactionOn;
  final String? note;
}

@immutable
class CoverEntryFormDraft {
  const CoverEntryFormDraft({
    this.amountText = '',
    this.method,
    required this.transactionOn,
    this.note = '',
  });

  final String amountText;
  final CoverEntryMethod? method;
  final DateTime transactionOn;
  final String note;

  String? get amountError {
    if (amountText.trim().isEmpty) {
      return 'Amount is required.';
    }

    final amount = parsedAmountCents;
    if (amount == null) {
      return 'Enter a valid amount.';
    }

    if (amount == 0) {
      return 'Amount must be non-zero.';
    }

    return null;
  }

  String? get methodError {
    if (method == null) {
      return 'Method is required.';
    }

    return null;
  }

  bool get isValid => amountError == null && methodError == null;

  int? get parsedAmountCents {
    if (amountText.trim().isEmpty) {
      return null;
    }

    final result = parseMoneyAmount(amountText);
    if (!result.isValid) {
      return null;
    }
    return result.cents;
  }

  SubmitCoverEntryInput toSubmission() {
    if (!isValid || method == null) {
      throw StateError('Cannot submit an invalid cover entry draft.');
    }

    return SubmitCoverEntryInput(
      amountCents: parsedAmountCents!,
      method: method!,
      transactionOn: transactionOn,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }
}

int suggestedCoverEntryAmountCents({
  required EventGuestRecord guest,
  List<GuestCoverEntryRecord> coverEntries = const [],
}) {
  if (guest.coverAmountCents <= 0 ||
      guest.coverStatus == CoverStatus.paid ||
      guest.coverStatus == CoverStatus.comped ||
      guest.coverStatus == CoverStatus.refunded) {
    return 0;
  }

  if (coverEntries.isEmpty) {
    return guest.coverStatus == CoverStatus.unpaid ? guest.coverAmountCents : 0;
  }

  final paidTotalCents = coverEntries.fold<int>(
    0,
    (total, entry) => total + entry.amountCents,
  );
  final remainingCents = guest.coverAmountCents - paidTotalCents;
  return remainingCents > 0 ? remainingCents : 0;
}
