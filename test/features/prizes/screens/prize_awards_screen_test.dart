import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/screens/prize_awards_screen.dart';

class _AwardsRepository implements PrizeRepository {
  _AwardsRepository(this.awards);

  List<PrizeAwardRecord> awards;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      awards;

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      awards;

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
  testWidgets('renders an intentional empty state when no locked awards exist',
      (tester) async {
    final repository = _AwardsRepository(const []);

    await tester.pumpWidget(
      MaterialApp(
        home: PrizeAwardsScreen(
          eventId: 'evt_01',
          guestNamesById: const {},
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No locked awards yet'), findsOneWidget);
    expect(
      find.text(
          'Preview and lock prize awards before using the payout checklist.'),
      findsOneWidget,
    );
  });

  testWidgets('renders locked awards without payment actions', (tester) async {
    final repository = _AwardsRepository(
      const [
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
        PrizeAwardRecord(
          id: 'award_02',
          eventId: 'evt_01',
          eventGuestId: 'gst_02',
          displayName: 'Bob Lee',
          rankStart: 2,
          rankEnd: 2,
          displayRank: '2',
          awardAmountCents: 10000,
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

    expect(find.text('Official Prize Awards'), findsOneWidget);
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text(r'$150.00'), findsOneWidget);
    expect(find.text(r'$100.00'), findsOneWidget);
    expect(find.text('Ready to Pay'), findsNothing);
    expect(find.text('Paid Out'), findsNothing);
    expect(find.text('Void Award'), findsNothing);
    expect(find.text('Mark Paid'), findsNothing);
    expect(find.text('Void'), findsNothing);
  });

  testWidgets('uses award display names when no fallback name map is provided',
      (tester) async {
    final repository = _AwardsRepository(
      const [
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
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrizeAwardsScreen(
          eventId: 'evt_01',
          guestNamesById: const {},
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('gst_01'), findsNothing);
  });
}
