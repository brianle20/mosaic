import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/features/prizes/models/prize_plan_draft.dart';

void main() {
  group('PrizePlanDraft', () {
    test('accepts none mode without tiers', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.none,
        reserveFixedCents: 0,
        reservePercentageBps: 0,
        tiers: [],
      );

      expect(draft.isValid, isTrue);
      expect(draft.generalError, isNull);
    });

    test('requires fixed amounts for fixed mode tiers', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.fixed,
        reserveFixedCents: 0,
        reservePercentageBps: 0,
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st'),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.tierErrors[1], contains('fixed amount'));
    });

    test('requires percentage values for percentage mode tiers', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.percentage,
        reserveFixedCents: 0,
        reservePercentageBps: 0,
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st'),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.tierErrors[1], contains('percentage'));
    });

    test('rejects duplicate tier places', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.fixed,
        reserveFixedCents: 0,
        reservePercentageBps: 0,
        tiers: [
          PrizeTierDraftInput(place: 1, fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 1, fixedAmountCents: 10000),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.generalError, contains('unique'));
    });

    test('rejects invalid reserve values', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.fixed,
        reserveFixedCents: -1,
        reservePercentageBps: 10001,
        tiers: [
          PrizeTierDraftInput(place: 1, fixedAmountCents: 15000),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.reserveFixedError, isNotNull);
      expect(draft.reservePercentageError, isNotNull);
    });

    test('converts to an upsert input payload when valid', () {
      const draft = PrizePlanDraft(
        prizeBudgetCents: 50000,
        mode: PrizePlanMode.fixed,
        reserveFixedCents: 5000,
        reservePercentageBps: 0,
        note: 'Top two paid',
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st', fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 2, label: '2nd', fixedAmountCents: 10000),
        ],
      );

      final input = draft.toUpsertInput(eventId: 'evt_01');

      expect(input.mode, PrizePlanMode.fixed);
      expect(input.reserveFixedCents, 5000);
      expect(input.note, 'Top two paid');
      expect(input.tiers.map((tier) => tier.place).toList(), [1, 2]);
    });
  });
}
