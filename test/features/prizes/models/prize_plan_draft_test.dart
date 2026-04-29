import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/features/prizes/models/prize_plan_draft.dart';

void main() {
  group('PrizePlanDraft', () {
    test('accepts none mode without tiers', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.none,
        tiers: [],
      );

      expect(draft.isValid, isTrue);
      expect(draft.generalError, isNull);
    });

    test('requires at least one positive fixed amount', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.fixed,
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st', fixedAmountCents: 0),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.generalError, 'Enter at least one prize amount.');
    });

    test('rejects duplicate tier places', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.fixed,
        tiers: [
          PrizeTierDraftInput(place: 1, fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 1, fixedAmountCents: 10000),
        ],
      );

      expect(draft.isValid, isFalse);
      expect(draft.generalError, contains('unique'));
    });

    test('computes total prizes from fixed tier amounts', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.fixed,
        tiers: [
          PrizeTierDraftInput(place: 1, fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 2, fixedAmountCents: 10000),
          PrizeTierDraftInput(place: 3, fixedAmountCents: 0),
        ],
      );

      expect(draft.totalPrizeCents, 25000);
    });

    test('derives ordinal labels when loading existing plans', () {
      final draft = PrizePlanDraft.fromDetail(
        PrizePlanDetail(
          plan: PrizePlanRecord.fromJson(
            const {
              'id': 'pp_01',
              'event_id': 'evt_01',
              'mode': 'fixed',
              'status': 'draft',
              'reserve_fixed_cents': 0,
              'reserve_percentage_bps': 0,
            },
          ),
          tiers: const [
            PrizeTierRecord(
              id: 'tier_01',
              prizePlanId: 'pp_01',
              place: 1,
              label: '1',
              fixedAmountCents: 4000,
            ),
            PrizeTierRecord(
              id: 'tier_02',
              prizePlanId: 'pp_01',
              place: 2,
              label: '2nd',
              fixedAmountCents: 2000,
            ),
          ],
        ),
      );

      expect(draft.tiers.map((tier) => tier.label).take(3), [
        '1st',
        '2nd',
        '3rd',
      ]);
    });

    test('filters zero amount placeholders out of the upsert payload', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.fixed,
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st', fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 2, label: '2nd', fixedAmountCents: 0),
          PrizeTierDraftInput(place: 3, label: '3rd', fixedAmountCents: 10000),
        ],
      );

      final input = draft.toUpsertInput(eventId: 'evt_01');

      expect(input.tiers.map((tier) => tier.place).toList(), [1, 2]);
      expect(input.tiers.map((tier) => tier.label).toList(), ['1st', '2nd']);
      expect(
        input.tiers.map((tier) => tier.fixedAmountCents).toList(),
        [15000, 10000],
      );
    });

    test('converts to an upsert input payload when valid', () {
      const draft = PrizePlanDraft(
        mode: PrizePlanMode.fixed,
        note: 'Top two paid',
        tiers: [
          PrizeTierDraftInput(place: 1, label: '1st', fixedAmountCents: 15000),
          PrizeTierDraftInput(place: 2, label: '2nd', fixedAmountCents: 10000),
        ],
      );

      final input = draft.toUpsertInput(eventId: 'evt_01');

      expect(input.mode, PrizePlanMode.fixed);
      expect(input.note, 'Top two paid');
      expect(input.tiers.map((tier) => tier.place).toList(), [1, 2]);
    });
  });
}
