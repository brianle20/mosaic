import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';

void main() {
  testWidgets('captures money amount and transaction date without time',
      (tester) async {
    final submissions = <SubmitCoverEntryInput>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final submission =
                      await Navigator.of(context).push<SubmitCoverEntryInput>(
                    MaterialPageRoute(
                      builder: (_) => AddCoverEntryScreen(
                        initialTransactionOn: DateTime(2026, 4, 23),
                      ),
                    ),
                  );
                  if (submission != null) {
                    submissions.add(submission);
                  }
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Amount'), findsOneWidget);
    expect(find.byType(MoneyTextFormField), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Apr 23, 2026'), findsOneWidget);
    expect(find.text('Time'), findsNothing);
    expect(find.text('Method is required.'), findsNothing);
    expect(tester.getSize(find.widgetWithText(TextFormField, 'Note')).height,
        lessThan(70));

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '500');
    expect(find.text('5.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Cover Entry'));
    await tester.pumpAndSettle();

    expect(submissions, hasLength(1));
    expect(submissions.single.amountCents, 500);
    expect(submissions.single.method, CoverEntryMethod.cash);
    expect(submissions.single.transactionOn, DateTime(2026, 4, 23));
  });

  testWidgets('shows method validation only after attempting save',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddCoverEntryScreen(
          initialTransactionOn: DateTime(2026, 4, 23),
        ),
      ),
    );

    expect(find.text('Method is required.'), findsNothing);

    await tester.tap(find.text('Save Cover Entry'));
    await tester.pump();

    expect(find.text('Method is required.'), findsOneWidget);
  });
}
