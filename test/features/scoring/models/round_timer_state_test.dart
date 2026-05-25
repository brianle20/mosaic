import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';

void main() {
  group('RoundTimerState', () {
    test('adds accumulated paused seconds to remaining time', () {
      final state = RoundTimerState.fromStartedAt(
        startedAt: DateTime.parse('2026-05-24T19:00:00Z'),
        pausedSeconds: 300,
        now: DateTime.parse('2026-05-24T19:59:00Z'),
      );

      expect(state.label, '06:00');
      expect(state.isExpired, isFalse);
    });

    test('freezes countdown while timer is paused', () {
      final state = RoundTimerState.fromStartedAt(
        startedAt: DateTime.parse('2026-05-24T19:00:00Z'),
        pausedAt: DateTime.parse('2026-05-24T19:25:00Z'),
        pausedSeconds: 120,
        now: DateTime.parse('2026-05-24T19:45:00Z'),
      );

      expect(state.label, '37:00');
      expect(state.isExpired, isFalse);
    });
  });
}
