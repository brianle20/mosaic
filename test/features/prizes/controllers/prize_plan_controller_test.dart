import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_plan_controller.dart';

class _FakePrizeRepository implements PrizeRepository {
  _FakePrizeRepository({
    this.cachedPlan,
    this.cachedPreview = const [],
    this.cachedAwards = const [],
    this.remotePlanLoader,
  });

  final PrizePlanDetail? cachedPlan;
  final List<PrizeAwardPreviewRow> cachedPreview;
  final List<PrizeAwardRecord> cachedAwards;
  final Future<PrizePlanDetail?> Function({
    required String eventId,
  })? remotePlanLoader;

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async =>
      cachedPlan;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
          String eventId) async =>
      cachedPreview;

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      cachedAwards;

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
  }) async {
    final loader = remotePlanLoader;
    if (loader != null) {
      return loader(eventId: eventId);
    }
    return cachedPlan;
  }

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      cachedAwards;

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) async =>
      const [];

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) {
    throw UnimplementedError();
  }
}

void main() {
  test('does not treat cached preview rows as a current payout preview',
      () async {
    final cachedPlan = PrizePlanDetail(
      plan: PrizePlanRecord.fromJson(
        const {
          'id': 'pp_01',
          'event_id': 'evt_01',
          'mode': 'fixed',
          'status': 'draft',
          'reserve_fixed_cents': 0,
          'reserve_percentage_bps': 0,
          'note': 'Draft plan',
        },
      ),
      tiers: const [
        PrizeTierRecord(
          id: 'tier_01',
          prizePlanId: 'pp_01',
          place: 1,
          label: '1st',
          fixedAmountCents: 15000,
        ),
      ],
    );

    final controller = PrizePlanController(
      eventId: 'evt_01',
      prizeRepository: _FakePrizeRepository(
        cachedPlan: cachedPlan,
        cachedPreview: const [
          PrizeAwardPreviewRow(
            eventGuestId: 'gst_01',
            displayName: 'Old Leader',
            rankStart: 1,
            rankEnd: 1,
            displayRank: '1',
            awardAmountCents: 15000,
          ),
        ],
      ),
    );

    await controller.load();

    expect(controller.previewRows, isEmpty);
    expect(controller.hasPreviewedPayouts, isFalse);
  });

  test('loads cached locked awards when remote prize-plan fetch fails',
      () async {
    final cachedPlan = PrizePlanDetail(
      plan: PrizePlanRecord.fromJson(
        const {
          'id': 'pp_01',
          'event_id': 'evt_01',
          'mode': 'fixed',
          'status': 'locked',
          'reserve_fixed_cents': 0,
          'reserve_percentage_bps': 0,
          'note': 'Locked plan',
        },
      ),
      tiers: const [
        PrizeTierRecord(
          id: 'tier_01',
          prizePlanId: 'pp_01',
          place: 1,
          label: '1st',
          fixedAmountCents: 15000,
        ),
      ],
    );
    const cachedAwards = [
      PrizeAwardRecord(
        id: 'award_01',
        eventId: 'evt_01',
        eventGuestId: 'gst_01',
        displayName: 'Alice Wong',
        rankStart: 1,
        rankEnd: 1,
        displayRank: '1',
        awardAmountCents: 15000,
      ),
    ];

    final controller = PrizePlanController(
      eventId: 'evt_01',
      prizeRepository: _FakePrizeRepository(
        cachedPlan: cachedPlan,
        cachedAwards: cachedAwards,
        remotePlanLoader: ({
          required String eventId,
        }) async =>
            throw Exception('temporary prize-plan failure'),
      ),
    );

    await controller.load();

    expect(controller.draft.mode, PrizePlanMode.fixed);
    expect(controller.lockedAwards.map((award) => award.id), ['award_01']);
    expect(controller.error, isNull);
  });
}
