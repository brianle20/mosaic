import 'package:meta/meta.dart';

enum StartSessionScanStep {
  scanTable,
  review,
}

@immutable
class StartSessionScanState {
  const StartSessionScanState({
    required this.tableTagUid,
  });

  factory StartSessionScanState.initial() {
    return const StartSessionScanState(
      tableTagUid: null,
    );
  }

  factory StartSessionScanState.withTableTag(String normalizedUid) {
    return StartSessionScanState(
      tableTagUid: normalizedUid,
    );
  }

  final String? tableTagUid;

  StartSessionScanStep get currentStep {
    if (tableTagUid == null) {
      return StartSessionScanStep.scanTable;
    }

    return StartSessionScanStep.review;
  }

  bool get canReview => tableTagUid != null;

  StartSessionScanState withTableTag(String normalizedUid) {
    return StartSessionScanState(
      tableTagUid: normalizedUid,
    );
  }
}
