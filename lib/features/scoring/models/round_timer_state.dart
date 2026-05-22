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

    return RoundTimerState(
      label: _formatCountdown(remaining),
      isExpired: false,
      isEndingSoon: remaining <= roundEndingSoonThreshold,
    );
  }

  final String label;
  final bool isExpired;
  final bool isEndingSoon;
}

String _formatCountdown(Duration remaining) {
  final totalSeconds = remaining.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
