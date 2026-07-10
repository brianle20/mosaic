abstract interface class OfflineRecoverySignal {
  int get generation;

  Stream<int> get generations;
}

enum OfflineRecoveryTrigger {
  startup,
  queuedWork,
  reachable,
  resumed,
  retry,
  manual,
}
