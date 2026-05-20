const roundLimitDuration = Duration(hours: 1);
const roundEndingSoonThreshold = Duration(minutes: 5);

class RoundTimerState {
  const RoundTimerState({
    required this.label,
    required this.isExpired,
    required this.isEndingSoon,
  });

  factory RoundTimerState.fromStartedAt({
    required DateTime startedAt,
    DateTime? now,
  }) {
    final remaining = startedAt.add(roundLimitDuration).difference(
          now ?? DateTime.now(),
        );
    if (remaining <= Duration.zero) {
      return const RoundTimerState(
        label: 'Time expired',
        isExpired: true,
        isEndingSoon: false,
      );
    }

    if (remaining < const Duration(minutes: 1)) {
      return const RoundTimerState(
        label: 'Less than 1 min left',
        isExpired: false,
        isEndingSoon: true,
      );
    }

    if (remaining <= roundEndingSoonThreshold) {
      return const RoundTimerState(
        label: 'Less than 5 min left',
        isExpired: false,
        isEndingSoon: true,
      );
    }

    return RoundTimerState(
      label: '${remaining.inMinutes} min left',
      isExpired: false,
      isEndingSoon: false,
    );
  }

  final String label;
  final bool isExpired;
  final bool isEndingSoon;
}
