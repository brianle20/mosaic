import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/sync_retry_scheduler.dart';

void main() {
  testWidgets('schedule replaces the prior timer and cancel prevents firing',
      (tester) async {
    final scheduler = TimerSyncRetryScheduler();
    var calls = 0;

    scheduler.schedule(const Duration(seconds: 1), () => calls += 1);
    scheduler.schedule(const Duration(seconds: 2), () => calls += 10);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);

    scheduler.cancel();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 0);
  });
}
