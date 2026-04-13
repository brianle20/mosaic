import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_awards_controller.dart';

class _FakePrizeRepository implements PrizeRepository {
  _FakePrizeRepository({
    required this.cachedAwards,
    this.loadAwards,
    this.markPaidHandler,
  });

  final List<PrizeAwardRecord> cachedAwards;
  final Future<List<PrizeAwardRecord>> Function(String eventId)? loadAwards;
  final Future<PrizeAwardRecord> Function(String awardId)? markPaidHandler;

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      cachedAwards;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async {
    final loader = loadAwards;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedAwards;
  }

  @override
  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  }) async {
    final handler = markPaidHandler;
    if (handler != null) {
      return handler(awardId);
    }
    throw UnimplementedError();
  }

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(String eventId) {
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
  test('loads cached awards when remote load fails', () async {
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

    final controller = PrizeAwardsController(
      eventId: 'evt_01',
      prizeRepository: _FakePrizeRepository(
        cachedAwards: cachedAwards,
        loadAwards: (_) async => throw Exception('temporary awards failure'),
      ),
    );

    await controller.load();

    expect(controller.awards.map((award) => award.id), ['award_01']);
    expect(controller.error, isNull);
  });

  test('markPaid preserves prize rank ordering', () async {
    final controller = PrizeAwardsController(
      eventId: 'evt_01',
      prizeRepository: _FakePrizeRepository(
        cachedAwards: const [],
        markPaidHandler: (_) async => const PrizeAwardRecord(
          id: 'award_02',
          eventId: 'evt_01',
          eventGuestId: 'gst_02',
          displayName: 'Bob Lee',
          rankStart: 2,
          rankEnd: 2,
          displayRank: '2',
          awardAmountCents: 10000,
          status: PrizeAwardStatus.paid,
        ),
      ),
    );
    controller.awards = const [
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
      PrizeAwardRecord(
        id: 'award_02',
        eventId: 'evt_01',
        eventGuestId: 'gst_02',
        displayName: 'Bob Lee',
        rankStart: 2,
        rankEnd: 2,
        displayRank: '2',
        awardAmountCents: 10000,
        status: PrizeAwardStatus.planned,
      ),
    ];

    await controller.markPaid('award_02');

    expect(
        controller.awards.map((award) => award.id), ['award_01', 'award_02']);
    expect(controller.awards.last.status, PrizeAwardStatus.paid);
  });
}
