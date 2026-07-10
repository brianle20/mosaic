import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mosaic/data/offline/offline_recovery_signal.dart';

class OfflineRecoveryScope extends InheritedWidget {
  const OfflineRecoveryScope({
    super.key,
    required this.signal,
    required super.child,
  });

  final OfflineRecoverySignal signal;

  static OfflineRecoverySignal? maybeSignalOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OfflineRecoveryScope>()
        ?.signal;
  }

  @override
  bool updateShouldNotify(OfflineRecoveryScope oldWidget) {
    return !identical(signal, oldWidget.signal);
  }
}

class ReconnectRefreshListener extends StatefulWidget {
  const ReconnectRefreshListener({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<ReconnectRefreshListener> createState() =>
      _ReconnectRefreshListenerState();
}

class _ReconnectRefreshListenerState extends State<ReconnectRefreshListener> {
  OfflineRecoverySignal? _signal;
  StreamSubscription<int>? _subscription;
  var _lastGeneration = 0;
  var _refreshing = false;
  var _refreshQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = OfflineRecoveryScope.maybeSignalOf(context);
    if (identical(next, _signal)) {
      return;
    }
    unawaited(_subscription?.cancel());
    _signal = next;
    _lastGeneration = next?.generation ?? 0;
    _subscription = next?.generations.listen(_handleGeneration);
  }

  void _handleGeneration(int generation) {
    if (!mounted || generation <= _lastGeneration) {
      return;
    }
    _lastGeneration = generation;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _refreshQueued = true;
    unawaited(_drainRefreshes());
  }

  Future<void> _drainRefreshes() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      while (mounted && _refreshQueued) {
        _refreshQueued = false;
        await widget.onRefresh();
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
