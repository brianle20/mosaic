import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_plan_controller.dart';

class _FakePrizeRepository implements PrizeRepository {
  _FakePrizeRepository({
    this.cachedPlan,
    this.cachedAwards = const [],
    this.remotePlanLoader,
  });

  final PrizePlanDetail? cachedPlan;
  final List<PrizeAwardRecord> cachedAwards;
  final Future<PrizePlanDetail?> Function({
    required String eventId,
    required int prizeBudgetCents,
  })? remotePlanLoader;

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async =>
      cachedPlan;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
          String eventId) async =>
      const [];

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      cachedAwards;

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  }) async {
    final loader = remotePlanLoader;
    if (loader != null) {
      return loader(eventId: eventId, prizeBudgetCents: prizeBudgetCents);
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
  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) {
    throw UnimplementedError();
  }

  @override
  Future<PrizeAwardRecord> voidPrizeAward({
    required String awardId,
    String? paidNote,
  }) {
    throw UnimplementedError();
  }
}

void main() {
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
        prizeBudgetCents: 50000,
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
        status: PrizeAwardStatus.planned,
      ),
    ];

    final controller = PrizePlanController(
      eventId: 'evt_01',
      prizeBudgetCents: 50000,
      prizeRepository: _FakePrizeRepository(
        cachedPlan: cachedPlan,
        cachedAwards: cachedAwards,
        remotePlanLoader: ({
          required String eventId,
          required int prizeBudgetCents,
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
