import 'package:flutter/material.dart';

abstract interface class OfflineRecoveryLifecycle {
  void setForeground(bool isForeground);
}

class OfflineRecoveryLifecycleListener extends StatefulWidget {
  const OfflineRecoveryLifecycleListener({
    super.key,
    required this.lifecycle,
    required this.child,
  });

  final OfflineRecoveryLifecycle lifecycle;
  final Widget child;

  @override
  State<OfflineRecoveryLifecycleListener> createState() =>
      _OfflineRecoveryLifecycleListenerState();
}

class _OfflineRecoveryLifecycleListenerState
    extends State<OfflineRecoveryLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.lifecycle.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
