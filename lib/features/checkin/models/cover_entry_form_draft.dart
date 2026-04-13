import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_models.dart';

@immutable
class SubmitCoverEntryInput {
  const SubmitCoverEntryInput({
    required this.amountCents,
    required this.method,
    this.note,
  });

  final int amountCents;
  final CoverEntryMethod method;
  final String? note;
}

@immutable
class CoverEntryFormDraft {
  const CoverEntryFormDraft({
    this.amountText = '',
    this.method,
    this.note = '',
  });

  final String amountText;
  final CoverEntryMethod? method;
  final String note;

  String? get amountError {
    if (amountText.trim().isEmpty) {
      return 'Amount is required.';
    }

    final amount = parsedAmountCents;
    if (amount == null) {
      return 'Amount must be a whole number.';
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
    final normalized = amountText.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  SubmitCoverEntryInput toSubmission() {
    if (!isValid || method == null) {
      throw StateError('Cannot submit an invalid cover entry draft.');
    }

    return SubmitCoverEntryInput(
      amountCents: parsedAmountCents!,
      method: method!,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }
}
