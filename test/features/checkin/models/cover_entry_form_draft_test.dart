import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';

void main() {
  group('CoverEntryFormDraft', () {
    test('requires an amount', () {
      final draft = CoverEntryFormDraft(
        amountText: '',
        method: CoverEntryMethod.cash,
        transactionOn: DateTime(2026, 4, 24),
      );

      expect(draft.amountError, 'Amount is required.');
    });

    test('rejects zero amount', () {
      final draft = CoverEntryFormDraft(
        amountText: r'$0.00',
        method: CoverEntryMethod.cash,
        transactionOn: DateTime(2026, 4, 24),
      );

      expect(draft.amountError, 'Amount must be non-zero.');
    });

    test('requires a method', () {
      final draft = CoverEntryFormDraft(
        amountText: r'$20.00',
        transactionOn: DateTime(2026, 4, 24),
      );

      expect(draft.methodError, 'Method is required.');
    });

    test('parses formatted money amounts as cents', () {
      final draft = CoverEntryFormDraft(
        amountText: r'$20.50',
        method: CoverEntryMethod.cash,
        transactionOn: DateTime(2026, 4, 24),
      );

      expect(draft.isValid, isTrue);
      expect(draft.parsedAmountCents, 2050);
    });

    test('builds repository input for a valid draft', () {
      final transactionOn = DateTime(2026, 4, 24);
      final draft = CoverEntryFormDraft(
        amountText: r'$20.00',
        method: CoverEntryMethod.venmo,
        note: 'Paid on arrival',
        transactionOn: transactionOn,
      );

      final input = draft.toSubmission();

      expect(input.amountCents, 2000);
      expect(input.method, CoverEntryMethod.venmo);
      expect(input.transactionOn, transactionOn);
      expect(input.note, 'Paid on arrival');
    });
  });
}
