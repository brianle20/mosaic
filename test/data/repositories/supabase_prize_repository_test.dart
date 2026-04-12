import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/supabase_prize_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabasePrizeRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads an existing prize plan with ordered tiers', () async {
      final cache = await LocalCache.create();
      final repository = SupabasePrizeRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        prizePlanLoader: (eventId) async => {
          'plan': {
            'id': 'pp_01',
            'event_id': eventId,
            'mode': 'fixed',
            'status': 'draft',
            'reserve_fixed_cents': 1000,
            'reserve_percentage_bps': 0,
            'note': 'Main event prizes',
            'row_version': 2,
          },
          'tiers': [
            {
              'id': 'tier_02',
              'prize_plan_id': 'pp_01',
              'place': 2,
              'label': 'Runner Up',
              'fixed_amount_cents': 10000,
              'percentage_bps': null,
            },
            {
              'id': 'tier_01',
              'prize_plan_id': 'pp_01',
              'place': 1,
              'label': 'Champion',
              'fixed_amount_cents': 15000,
              'percentage_bps': null,
            },
          ],
        },
      );

      final detail = await repository.loadPrizePlan(
        eventId: 'evt_01',
        prizeBudgetCents: 30000,
      );

      expect(detail, isNotNull);
      expect(detail!.plan.mode, PrizePlanMode.fixed);
      expect(detail.tiers.map((tier) => tier.place).toList(), [1, 2]);
      expect(detail.tiers.first.fixedAmountCents, 15000);

      final cached = await repository.readCachedPrizePlan('evt_01');
      expect(cached?.tiers.map((tier) => tier.place).toList(), [1, 2]);
    });

    test('upserts a prize plan and returns the saved detail', () async {
      final cache = await LocalCache.create();
      final repository = SupabasePrizeRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        prizeMutationRunner: (functionName, params) async {
          expect(functionName, 'upsert_prize_plan');
          expect(params['target_event_id'], 'evt_01');
          return {
            'plan': {
              'id': 'pp_01',
              'event_id': 'evt_01',
              'mode': 'percentage',
              'status': 'draft',
              'reserve_fixed_cents': 0,
              'reserve_percentage_bps': 1000,
              'note': 'Percent split',
              'row_version': 3,
            },
            'tiers': [
              {
                'id': 'tier_01',
                'prize_plan_id': 'pp_01',
                'place': 1,
                'label': '1st',
                'fixed_amount_cents': null,
                'percentage_bps': 5000,
              },
            ],
          };
        },
      );

      final detail = await repository.upsertPrizePlan(
        UpsertPrizePlanInput(
          eventId: 'evt_01',
          prizeBudgetCents: 50000,
          mode: PrizePlanMode.percentage,
          reserveFixedCents: 0,
          reservePercentageBps: 1000,
          note: 'Percent split',
          tiers: const [
            PrizeTierDraftInput(place: 1, label: '1st', percentageBps: 5000),
          ],
        ),
      );

      expect(detail.plan.mode, PrizePlanMode.percentage);
      expect(detail.tiers.single.percentageBps, 5000);
    });

    test('loads preview rows and refreshes cached preview', () async {
      final cache = await LocalCache.create();
      final repository = SupabasePrizeRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        prizePreviewLoader: (_) async => [
          {
            'event_guest_id': 'gst_01',
            'display_name': 'Alice Wong',
            'rank_start': 1,
            'rank_end': 1,
            'display_rank': '1',
            'award_amount_cents': 15000,
          },
          {
            'event_guest_id': 'gst_02',
            'display_name': 'Bob Lee',
            'rank_start': 2,
            'rank_end': 3,
            'display_rank': 'T-2',
            'award_amount_cents': 7500,
          },
        ],
      );

      final preview = await repository.loadPrizePreview('evt_01');

      expect(preview, hasLength(2));
      expect(preview.first.displayName, 'Alice Wong');
      expect(preview.last.displayRank, 'T-2');

      final cached = await repository.readCachedPrizePreview('evt_01');
      expect(cached, hasLength(2));
      expect(cached.last.awardAmountCents, 7500);
    });

    test('locks awards and updates cached locked awards', () async {
      final cache = await LocalCache.create();
      final repository = SupabasePrizeRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        prizeAwardsLoader: (_) async => [
          {
            'id': 'award_01',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_01',
            'rank_start': 1,
            'rank_end': 1,
            'display_rank': '1',
            'award_amount_cents': 15000,
            'status': 'planned',
            'paid_method': null,
            'paid_at': null,
            'paid_note': null,
          },
        ],
        prizeMutationRunner: (functionName, params) async {
          expect(functionName, 'lock_prize_awards');
          return {
            'rows': [
              {
                'id': 'award_01',
                'event_id': 'evt_01',
                'event_guest_id': 'gst_01',
                'rank_start': 1,
                'rank_end': 1,
                'display_rank': '1',
                'award_amount_cents': 15000,
                'status': 'planned',
                'paid_method': null,
                'paid_at': null,
                'paid_note': null,
              },
            ],
          };
        },
      );

      final awards = await repository.lockPrizeAwards('evt_01');

      expect(awards, hasLength(1));
      expect(awards.single.status, PrizeAwardStatus.planned);

      final cached = await repository.readCachedPrizeAwards('evt_01');
      expect(cached, hasLength(1));
      expect(cached.single.awardAmountCents, 15000);
    });

    test('maps paid and void prize award mutations', () async {
      final cache = await LocalCache.create();
      final repository = SupabasePrizeRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        prizeMutationRunner: (functionName, params) async {
          if (functionName == 'mark_prize_award_paid') {
            return {
              'id': 'award_01',
              'event_id': 'evt_01',
              'event_guest_id': 'gst_01',
              'rank_start': 1,
              'rank_end': 1,
              'display_rank': '1',
              'award_amount_cents': 15000,
              'status': 'paid',
              'paid_method': 'cash',
              'paid_at': '2026-04-12T03:00:00Z',
              'paid_note': 'Paid at venue',
            };
          }

          return {
            'id': 'award_02',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_02',
            'rank_start': 2,
            'rank_end': 2,
            'display_rank': '2',
            'award_amount_cents': 10000,
            'status': 'void',
            'paid_method': null,
            'paid_at': null,
            'paid_note': 'Left early',
          };
        },
      );

      final paid = await repository.markPrizeAwardPaid(
        awardId: 'award_01',
        paidMethod: 'cash',
        paidNote: 'Paid at venue',
      );
      final voided = await repository.voidPrizeAward(
        awardId: 'award_02',
        paidNote: 'Left early',
      );

      expect(paid.status, PrizeAwardStatus.paid);
      expect(paid.paidMethod, 'cash');
      expect(voided.status, PrizeAwardStatus.voided);
      expect(voided.paidNote, 'Left early');
    });
  });
}
