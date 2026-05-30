import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/widgets/keyboard_dismiss_region.dart';

void main() {
  testWidgets('dismisses the keyboard when tapping outside the focused field',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyboardDismissRegion(
          child: Scaffold(
            body: Column(
              children: [
                TextField(key: Key('field')),
                Text('Outside field'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Outside field'));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('keeps the keyboard open when tapping inside the focused field',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyboardDismissRegion(
          child: Scaffold(
            body: TextField(key: Key('field')),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });
}
