import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

void main() {
  group('StartSessionScanState', () {
    test('advances seat prompts east south west north after table scan', () {
      final state = StartSessionScanState.initial()
          .withTableTag('TABLE-001')
          .withPlayerTag('PLAYER-EAST')
          .withPlayerTag('PLAYER-SOUTH');

      expect(state.currentStep, StartSessionScanStep.scanWest);
      expect(state.currentSeatLabel, 'West');
    });

    test('rejects duplicate player-tag scans', () {
      final state = StartSessionScanState.initial()
          .withTableTag('TABLE-001')
          .withPlayerTag('PLAYER-EAST');

      expect(
        () => state.withPlayerTag('PLAYER-EAST'),
        throwsA(isA<StateError>()),
      );
    });

    test('enters review state only after all four seats are resolved', () {
      final completeState = StartSessionScanState.initial()
          .withTableTag('TABLE-001')
          .withPlayerTag('PLAYER-EAST')
          .withPlayerTag('PLAYER-SOUTH')
          .withPlayerTag('PLAYER-WEST')
          .withPlayerTag('PLAYER-NORTH');

      expect(completeState.currentStep, StartSessionScanStep.review);
      expect(completeState.canReview, isTrue);
      expect(completeState.scannedPlayerUids, [
        'PLAYER-EAST',
        'PLAYER-SOUTH',
        'PLAYER-WEST',
        'PLAYER-NORTH',
      ]);
    });
  });
}
