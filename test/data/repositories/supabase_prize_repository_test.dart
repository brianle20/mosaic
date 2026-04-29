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
              'mode': 'fixed',
              'status': 'draft',
              'reserve_fixed_cents': 0,
              'reserve_percentage_bps': 0,
              'note': 'Fixed split',
              'row_version': 3,
            },
            'tiers': [
              {
                'id': 'tier_01',
                'prize_plan_id': 'pp_01',
                'place': 1,
                'label': '1st',
                'fixed_amount_cents': 15000,
                'percentage_bps': null,
              },
            ],
          };
        },
      );

      final detail = await repository.upsertPrizePlan(
        UpsertPrizePlanInput(
          eventId: 'evt_01',
          mode: PrizePlanMode.fixed,
          note: 'Fixed split',
          tiers: const [
            PrizeTierDraftInput(
              place: 1,
              label: '1st',
              fixedAmountCents: 15000,
            ),
          ],
        ),
      );

      expect(detail.plan.mode, PrizePlanMode.fixed);
      expect(detail.tiers.single.fixedAmountCents, 15000);
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
              },
            ],
          };
        },
      );

      final awards = await repository.lockPrizeAwards('evt_01');

      expect(awards, hasLength(1));
      expect(awards.single.toJson().containsKey('status'), isFalse);

      final cached = await repository.readCachedPrizeAwards('evt_01');
      expect(cached, hasLength(1));
      expect(cached.single.awardAmountCents, 15000);
    });
  });
}
