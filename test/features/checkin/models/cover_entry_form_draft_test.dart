import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';

void main() {
  group('CoverEntryFormDraft', () {
    test('requires an amount', () {
      const draft = CoverEntryFormDraft(
        amountText: '',
        method: CoverEntryMethod.cash,
      );

      expect(draft.amountError, 'Amount is required.');
    });

    test('rejects zero amount', () {
      const draft = CoverEntryFormDraft(
        amountText: '0',
        method: CoverEntryMethod.cash,
      );

      expect(draft.amountError, 'Amount must be non-zero.');
    });

    test('requires a method', () {
      const draft = CoverEntryFormDraft(
        amountText: '2000',
      );

      expect(draft.methodError, 'Method is required.');
    });

    test('accepts negative refund amount', () {
      const draft = CoverEntryFormDraft(
        amountText: '-500',
        method: CoverEntryMethod.refund,
        note: 'Refunded duplicate payment',
      );

      expect(draft.isValid, isTrue);
      expect(draft.parsedAmountCents, -500);
    });

    test('builds repository input for a valid draft', () {
      const draft = CoverEntryFormDraft(
        amountText: '2000',
        method: CoverEntryMethod.venmo,
        note: 'Paid on arrival',
      );

      final input = draft.toSubmission();

      expect(input.amountCents, 2000);
      expect(input.method, CoverEntryMethod.venmo);
      expect(input.note, 'Paid on arrival');
    });
  });
}
