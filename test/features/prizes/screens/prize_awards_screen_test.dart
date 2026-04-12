import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/screens/prize_awards_screen.dart';

class _AwardsRepository implements PrizeRepository {
  _AwardsRepository(this.awards);

  List<PrizeAwardRecord> awards;
  int markPaidCount = 0;
  int voidCount = 0;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      awards;

  @override
  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  }) async {
    markPaidCount += 1;
    final updated = PrizeAwardRecord(
      id: awardId,
      eventId: 'evt_01',
      eventGuestId: 'gst_01',
      rankStart: 1,
      rankEnd: 1,
      displayRank: '1',
      awardAmountCents: 15000,
      status: PrizeAwardStatus.paid,
      paidMethod: paidMethod,
      paidNote: paidNote,
    );
    awards = [updated, ...awards.where((award) => award.id != awardId)];
    return updated;
  }

  @override
  Future<PrizeAwardRecord> voidPrizeAward({
    required String awardId,
    String? paidNote,
  }) async {
    voidCount += 1;
    final updated = PrizeAwardRecord(
      id: awardId,
      eventId: 'evt_01',
      eventGuestId: 'gst_02',
      rankStart: 2,
      rankEnd: 2,
      displayRank: '2',
      awardAmountCents: 10000,
      status: PrizeAwardStatus.voided,
      paidNote: paidNote,
    );
    awards = [awards.first, updated];
    return updated;
  }

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      awards;

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
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async => null;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
    String eventId,
  ) async =>
      const [];

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders locked awards and updates statuses', (tester) async {
    final repository = _AwardsRepository(
      const [
        PrizeAwardRecord(
          id: 'award_01',
          eventId: 'evt_01',
          eventGuestId: 'gst_01',
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
          rankStart: 2,
          rankEnd: 2,
          displayRank: '2',
          awardAmountCents: 10000,
          status: PrizeAwardStatus.planned,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrizeAwardsScreen(
          eventId: 'evt_01',
          guestNamesById: const {
            'gst_01': 'Alice Wong',
            'gst_02': 'Bob Lee',
          },
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('planned'), findsNWidgets(2));

    await tester.tap(find.text('Mark Paid').first);
    await tester.pumpAndSettle();
    expect(repository.markPaidCount, 1);
    expect(find.text('paid'), findsOneWidget);

    await tester.tap(find.text('Void').first);
    await tester.pumpAndSettle();
    expect(repository.voidCount, 1);
    expect(find.text('void'), findsOneWidget);
  });
}
