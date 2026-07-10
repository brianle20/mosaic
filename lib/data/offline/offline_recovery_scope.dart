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
    this.routeAware = true,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool routeAware;

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
  var _listenerToken = 0;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;
  Timer? _routeReturnTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route?.animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimation);
      _routeAnimation = route?.animation;
      _routeAnimation?.addStatusListener(_handleRouteAnimation);
    }
    if (!identical(route?.secondaryAnimation, _secondaryAnimation)) {
      _secondaryAnimation?.removeStatusListener(_handleRouteAnimation);
      _secondaryAnimation = route?.secondaryAnimation;
      _secondaryAnimation?.addStatusListener(_handleRouteAnimation);
    }
    final next = OfflineRecoveryScope.maybeSignalOf(context);
    if (identical(next, _signal)) {
      return;
    }
    final token = ++_listenerToken;
    unawaited(_subscription?.cancel());
    _signal = next;
    _lastGeneration = next?.generation ?? 0;
    _refreshQueued = false;
    _subscription = next?.generations.listen(
      (generation) => _handleGeneration(token, generation),
    );
    if (widget.routeAware &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        _refreshQueued) {
      unawaited(_drainRefreshes(token));
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (!widget.routeAware ||
        !mounted ||
        (status != AnimationStatus.completed &&
            status != AnimationStatus.dismissed) ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !_refreshQueued) {
      return;
    }
    unawaited(_drainRefreshes(_listenerToken));
  }

  void _handleGeneration(int token, int generation) {
    if (!mounted || token != _listenerToken || generation <= _lastGeneration) {
      return;
    }
    _lastGeneration = generation;
    if (widget.routeAware && !(ModalRoute.of(context)?.isCurrent ?? true)) {
      _refreshQueued = true;
      _watchForRouteReturn(token);
      return;
    }
    _refreshQueued = true;
    unawaited(_drainRefreshes(token));
  }

  void _watchForRouteReturn(int token) {
    if (!mounted || token != _listenerToken || !_refreshQueued) return;
    _routeReturnTimer?.cancel();
    _routeReturnTimer = Timer(const Duration(milliseconds: 250), () {
      _routeReturnTimer = null;
      if (!mounted || token != _listenerToken || !_refreshQueued) return;
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        unawaited(_drainRefreshes(token));
      } else {
        _watchForRouteReturn(token);
      }
    });
  }

  Future<void> _drainRefreshes(int token) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      while (mounted && token == _listenerToken && _refreshQueued) {
        _refreshQueued = false;
        if (!mounted || token != _listenerToken) {
          break;
        }
        if (widget.routeAware && !(ModalRoute.of(context)?.isCurrent ?? true)) {
          break;
        }
        await widget.onRefresh();
      }
    } finally {
      _refreshing = false;
      if (mounted && _refreshQueued) {
        unawaited(_drainRefreshes(_listenerToken));
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _secondaryAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeReturnTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routeAware &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        _refreshQueued) {
      unawaited(_drainRefreshes(_listenerToken));
    }
    return widget.child;
  }
}
