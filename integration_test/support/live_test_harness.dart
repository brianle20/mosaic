import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mosaic/main.dart' as app;

import 'live_test_config.dart';

void ensureIntegrationTestBinding() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

Future<void> bootAndSignIn(WidgetTester tester) async {
  assertLiveCredentialsConfigured();

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  app.main();
  await tester.pump();

  await pumpUntilAny(
    tester,
    <Finder>[
      find.text('Host Sign In'),
      find.text('Events'),
      find.textContaining('SUPABASE_'),
    ],
  );

  if (find.text('Sign out').evaluate().isNotEmpty) {
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await pumpUntilVisible(tester, find.text('Host Sign In'));
  }

  expect(find.text('Host Sign In'), findsOneWidget);

  await tester.enterText(find.byType(TextFormField).at(0), liveHostEmail);
  await tester.enterText(find.byType(TextFormField).at(1), liveHostPassword);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
  await tester.pump();

  await pumpUntilVisible(
    tester,
    find.widgetWithText(FilledButton, 'Create Event'),
  );
}

Future<void> pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for ${finder.describeMatch(Plurality.many)}');
}

Future<void> pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
  }

  fail(
    'Timed out waiting for any of: ${finders.map((finder) => finder.describeMatch(Plurality.many)).join(', ')}',
  );
}

Future<void> tapBack(WidgetTester tester) async {
  final backButton = find.byTooltip('Back').hitTestable().first;
  await pumpUntilVisible(tester, backButton);
  await tester.tap(backButton);
}
