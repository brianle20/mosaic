import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/offline_recovery_lifecycle.dart';

class _FakeOfflineRecoveryLifecycle implements OfflineRecoveryLifecycle {
  final foregroundValues = <bool>[];

  @override
  void setForeground(bool isForeground) {
    foregroundValues.add(isForeground);
  }
}

void main() {
  testWidgets('forwards background and resume to recovery coordinator',
      (tester) async {
    final lifecycle = _FakeOfflineRecoveryLifecycle();
    await tester.pumpWidget(
      OfflineRecoveryLifecycleListener(
        lifecycle: lifecycle,
        child: const MaterialApp(home: SizedBox()),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(lifecycle.foregroundValues, [false, true]);
  });
}
