// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';

class _RecordingPrizeRepository implements PrizeRepository {
  _RecordingPrizeRepository({
    this.loadedPlan,
    this.upsertedPlan,
    this.previewRows = const [],
    this.lockedAwards = const [],
  });

  final PrizePlanDetail? loadedPlan;
  final PrizePlanDetail? upsertedPlan;
  final List<PrizeAwardPreviewRow> previewRows;
  final List<PrizeAwardRecord> lockedAwards;
  int previewCount = 0;
  int lockCount = 0;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      lockedAwards;

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  }) async =>
      loadedPlan;

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) async {
    previewCount += 1;
    return previewRows;
  }

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) async {
    lockCount += 1;
    return lockedAwards;
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
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async =>
      loadedPlan;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
    String eventId,
  ) async =>
      const [];

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) async {
    return upsertedPlan ?? loadedPlan!;
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
  testWidgets('renders budget and prize mode controls', (tester) async {
    final repository = _RecordingPrizeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeBudgetCents: 50000,
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prize Budget'), findsOneWidget);
    expect(find.text('50000 cents'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Percentage'), findsOneWidget);
    expect(
      find.text('Preview awards before locking the official payout list.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows validation and blocks preview when fixed mode has no tiers',
      (tester) async {
    final repository = _RecordingPrizeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeBudgetCents: 50000,
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fixed'));
    await tester.pumpAndSettle();
    final previewButton = find.text('Preview Awards');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('Prize tiers are required.'), findsNWidgets(2));
    expect(repository.previewCount, 0);
  });

  testWidgets('shows preview rows and allows locking valid awards',
      (tester) async {
    final loadedPlan = PrizePlanDetail(
      plan: PrizePlanRecord.fromJson(
        const {
          'id': 'pp_01',
          'event_id': 'evt_01',
          'mode': 'fixed',
          'status': 'draft',
          'reserve_fixed_cents': 0,
          'reserve_percentage_bps': 0,
          'note': 'Top two',
          'row_version': 1,
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
    final repository = _RecordingPrizeRepository(
      upsertedPlan: loadedPlan,
      previewRows: const [
        PrizeAwardPreviewRow(
          eventGuestId: 'gst_01',
          displayName: 'Alice Wong',
          rankStart: 1,
          rankEnd: 1,
          displayRank: '1',
          awardAmountCents: 15000,
        ),
      ],
      lockedAwards: const [
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
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeBudgetCents: 50000,
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fixed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Tier'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'), '15000');
    await tester.pumpAndSettle();

    final previewButton = find.text('Preview Awards');
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      previewButton,
      200,
      scrollable: scrollable,
    );
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(repository.previewCount, 1);
    expect(find.text('Preview Awards'), findsWidgets);
    expect(
      find.text(
          'Lock awards only when this preview matches the standings you want to pay out.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Alice Wong'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('15000 cents'), findsWidgets);

    final lockButton = find.text('Lock Prize Awards');
    await tester.scrollUntilVisible(
      lockButton,
      200,
      scrollable: scrollable,
    );
    await tester.tap(lockButton);
    await tester.pumpAndSettle();

    expect(repository.lockCount, 1);
  });
}
