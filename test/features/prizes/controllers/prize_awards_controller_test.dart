import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_awards_controller.dart';

class _FakePrizeRepository implements PrizeRepository {
  _FakePrizeRepository({
    required this.cachedAwards,
    this.loadAwards,
  });

  final List<PrizeAwardRecord> cachedAwards;
  final Future<List<PrizeAwardRecord>> Function(String eventId)? loadAwards;

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
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
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
}

void main() {
  test('stale prize load cannot overwrite a newer recovery load', () async {
    final firstRemote = Completer<List<PrizeAwardRecord>>();
    final firstRemoteStarted = Completer<void>();
    final secondRemote = Completer<List<PrizeAwardRecord>>();
    final secondRemoteStarted = Completer<void>();
    var loadCount = 0;
    const cached = PrizeAwardRecord(
      id: 'award_cached',
      eventId: 'evt_01',
      eventGuestId: 'gst_cached',
      displayName: 'Cached Player',
      rankStart: 1,
      rankEnd: 1,
      displayRank: '1',
      awardAmountCents: 100,
    );
    const recovered = PrizeAwardRecord(
      id: 'award_recovered',
      eventId: 'evt_01',
      eventGuestId: 'gst_recovered',
      displayName: 'Recovered Player',
      rankStart: 1,
      rankEnd: 1,
      displayRank: '1',
      awardAmountCents: 200,
    );
    final repository = _FakePrizeRepository(
      cachedAwards: [cached],
      loadAwards: (_) {
        loadCount += 1;
        if (loadCount == 1) {
          firstRemoteStarted.complete();
          return firstRemote.future;
        }
        secondRemoteStarted.complete();
        return secondRemote.future;
      },
    );
    final controller = PrizeAwardsController(
      eventId: 'evt_01',
      prizeRepository: repository,
    );

    final firstLoad = controller.load();
    await firstRemoteStarted.future;
    final secondLoad = controller.load();
    await secondRemoteStarted.future;

    firstRemote.complete([cached]);
    await firstLoad;
    expect(controller.isLoading, isTrue);

    secondRemote.complete([recovered]);
    await secondLoad;
    expect(controller.awards.single.displayName, 'Recovered Player');
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

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
}
