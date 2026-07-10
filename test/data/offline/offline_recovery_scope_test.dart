import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/offline/offline_recovery_signal.dart';

class _FakeOfflineRecoverySignal implements OfflineRecoverySignal {
  final StreamController<int> _controller =
      StreamController<int>.broadcast(sync: true);
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  Stream<int> get generations => _controller.stream;

  void emit() {
    _generation += 1;
    _controller.add(_generation);
  }

  void emitSameGeneration() {
    _controller.add(_generation);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('current route refreshes once for a settled generation',
      (tester) async {
    final signal = _FakeOfflineRecoverySignal();
    addTearDown(signal.dispose);
    var refreshCount = 0;
    await tester.pumpWidget(
      OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          home: ReconnectRefreshListener(
            onRefresh: () async => refreshCount += 1,
            child: const Text('cached content'),
          ),
        ),
      ),
    );

    signal.emit();
    await tester.pump();
    expect(refreshCount, 1);

    signal.emitSameGeneration();
    await tester.pump();
    expect(refreshCount, 1);
  });

  testWidgets('overlapping generations coalesce to one follow-up refresh',
      (tester) async {
    final signal = _FakeOfflineRecoverySignal();
    addTearDown(signal.dispose);
    final firstRefresh = Completer<void>();
    var refreshCount = 0;
    await tester.pumpWidget(
      OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          home: ReconnectRefreshListener(
            onRefresh: () async {
              refreshCount += 1;
              if (refreshCount == 1) {
                await firstRefresh.future;
              }
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );

    signal.emit();
    signal.emit();
    signal.emit();
    await tester.pump();
    expect(refreshCount, 1);

    firstRefresh.complete();
    await tester.pumpAndSettle();
    expect(refreshCount, 2);
  });

  testWidgets('hidden route ignores recovery generation', (tester) async {
    final signal = _FakeOfflineRecoverySignal();
    addTearDown(signal.dispose);
    var refreshCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: ReconnectRefreshListener(
            onRefresh: () async => refreshCount += 1,
            child: const Text('underlying route'),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('top route')),
    );
    await tester.pumpAndSettle();

    signal.emit();
    await tester.pump();
    expect(refreshCount, 0);
  });

  testWidgets('covered route drops a queued follow-up refresh', (tester) async {
    final signal = _FakeOfflineRecoverySignal();
    addTearDown(signal.dispose);
    final firstRefresh = Completer<void>();
    final navigatorKey = GlobalKey<NavigatorState>();
    var refreshCount = 0;
    await tester.pumpWidget(
      OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: ReconnectRefreshListener(
            onRefresh: () async {
              refreshCount += 1;
              if (refreshCount == 1) {
                await firstRefresh.future;
              }
            },
            child: const Text('underlying route'),
          ),
        ),
      ),
    );

    signal.emit();
    signal.emit();
    await tester.pump();
    expect(refreshCount, 1);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('top route')),
    );
    await tester.pumpAndSettle();
    firstRefresh.complete();
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
  });

  testWidgets('rebind drops queued refreshes from the old signal',
      (tester) async {
    final oldSignal = _FakeOfflineRecoverySignal();
    final newSignal = _FakeOfflineRecoverySignal();
    addTearDown(oldSignal.dispose);
    addTearDown(newSignal.dispose);
    final firstRefresh = Completer<void>();
    var refreshCount = 0;

    Widget build(OfflineRecoverySignal signal) {
      return OfflineRecoveryScope(
        signal: signal,
        child: MaterialApp(
          home: ReconnectRefreshListener(
            onRefresh: () async {
              refreshCount += 1;
              if (refreshCount == 1) {
                await firstRefresh.future;
              }
            },
            child: const SizedBox(),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(oldSignal));
    oldSignal.emit();
    oldSignal.emit();
    await tester.pump();
    expect(refreshCount, 1);

    await tester.pumpWidget(build(newSignal));
    await tester.pump();
    firstRefresh.complete();
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
  });
}
