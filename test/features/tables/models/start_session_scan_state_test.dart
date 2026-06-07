import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

void main() {
  group('StartSessionScanState', () {
    test('starts by asking for a table tag', () {
      final state = StartSessionScanState.initial();

      expect(state.tableTagUid, isNull);
      expect(state.currentStep, StartSessionScanStep.scanTable);
      expect(state.canReview, isFalse);
    });

    test('enters review state after table tag scan', () {
      final state = StartSessionScanState.initial().withTableTag('TABLE-001');

      expect(state.tableTagUid, 'TABLE-001');
      expect(state.currentStep, StartSessionScanStep.review);
      expect(state.canReview, isTrue);
    });
  });
}
