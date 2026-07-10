import 'dart:async';

abstract interface class SyncRetryScheduler {
  void schedule(Duration delay, void Function() callback);
  void cancel();
}

class TimerSyncRetryScheduler implements SyncRetryScheduler {
  Timer? _timer;

  @override
  void schedule(Duration delay, void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
