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
  UpsertPrizePlanInput? capturedInput;
  int previewCount = 0;
  int lockCount = 0;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      lockedAwards;

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
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
    capturedInput = input;
    return upsertedPlan ?? loadedPlan!;
  }
}

void main() {
  testWidgets('renders derived total and fixed prize controls', (tester) async {
    final repository = _RecordingPrizeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prize Budget'), findsNothing);
    expect(find.text('Total Prizes'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
    expect(find.text('Paid Places'), findsOneWidget);
    expect(find.text('None'), findsNothing);
    expect(find.text('Fixed'), findsNothing);
    expect(find.text('Percentage'), findsNothing);
    expect(
      find.text('Preview awards before locking the official payout list.'),
      findsOneWidget,
    );
    expect(
      find.text('Enter prize amounts when you are ready to preview payouts.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows validation and blocks preview when no positive prizes exist',
      (tester) async {
    final repository = _RecordingPrizeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.text('Save & Preview Payouts');
    await tester.scrollUntilVisible(
      previewButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter at least one prize amount.'), findsOneWidget);
    expect(repository.previewCount, 0);
  });

  testWidgets('updates total in dollars and ignores zero prize placeholders',
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
          'row_version': 1,
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
        PrizeTierRecord(
          id: 'tier_02',
          prizePlanId: 'pp_01',
          place: 2,
          label: '2nd',
          fixedAmountCents: 10000,
        ),
      ],
    );
    final repository = _RecordingPrizeRepository(upsertedPlan: loadedPlan);

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountFields = find.widgetWithText(TextFormField, 'Amount');
    expect(amountFields, findsNWidgets(3));

    await tester.enterText(amountFields.at(0), '15000');
    await tester.enterText(amountFields.at(1), '0');
    await tester.enterText(amountFields.at(2), '10000');
    await tester.pumpAndSettle();

    expect(find.text(r'$250.00'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Save & Preview Payouts'),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Save & Preview Payouts'));
    await tester.pumpAndSettle();

    expect(repository.previewCount, 1);
    expect(
      repository.capturedInput!.tiers.map((tier) => tier.place).toList(),
      [1, 2],
    );
    expect(
      repository.capturedInput!.tiers.map((tier) => tier.fixedAmountCents),
      [15000, 10000],
    );
  });

  testWidgets('shows an explicit empty result when no payouts can be previewed',
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
          'row_version': 1,
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
    final repository = _RecordingPrizeRepository(upsertedPlan: loadedPlan);

    await tester.pumpWidget(
      MaterialApp(
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '15000',
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Save & Preview Payouts'),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Save & Preview Payouts'));
    await tester.pumpAndSettle();

    expect(repository.previewCount, 1);
    expect(find.text('No scored players yet'), findsOneWidget);
    expect(
      find.text('Add scores before previewing payouts.'),
      findsOneWidget,
    );
    expect(find.text('Lock Prize Awards'), findsNothing);
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
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '15000',
    );
    await tester.pumpAndSettle();

    final previewButton = find.text('Save & Preview Payouts');
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      previewButton,
      200,
      scrollable: scrollable,
    );
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(repository.previewCount, 1);
    expect(find.text('Save & Preview Payouts'), findsWidgets);
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
    expect(find.text(r'$150.00'), findsWidgets);

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

  testWidgets(
      'shows locked awards action when reopening an already locked plan',
      (tester) async {
    final loadedPlan = PrizePlanDetail(
      plan: PrizePlanRecord.fromJson(
        const {
          'id': 'pp_01',
          'event_id': 'evt_01',
          'mode': 'fixed',
          'status': 'locked',
          'reserve_fixed_cents': 0,
          'reserve_percentage_bps': 0,
          'note': 'Locked plan',
          'row_version': 1,
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
    final repository = _RecordingPrizeRepository(
      loadedPlan: loadedPlan,
      lockedAwards: const [
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
        home: PrizePlanScreen(
          eventId: 'evt_01',
          prizeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Locked Awards Available'),
      200,
      scrollable: scrollable,
    );

    expect(find.text('Locked Awards Available'), findsOneWidget);
    expect(find.text('View Locked Awards'), findsOneWidget);
  });
}
