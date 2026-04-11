import 'package:meta/meta.dart';

enum StartSessionScanStep {
  scanTable,
  scanEast,
  scanSouth,
  scanWest,
  scanNorth,
  review,
}

@immutable
class StartSessionScanState {
  const StartSessionScanState({
    required this.tableTagUid,
    required this.scannedPlayerUids,
  });

  factory StartSessionScanState.initial() {
    return const StartSessionScanState(
      tableTagUid: null,
      scannedPlayerUids: [],
    );
  }

  final String? tableTagUid;
  final List<String> scannedPlayerUids;

  StartSessionScanStep get currentStep {
    if (tableTagUid == null) {
      return StartSessionScanStep.scanTable;
    }

    return switch (scannedPlayerUids.length) {
      0 => StartSessionScanStep.scanEast,
      1 => StartSessionScanStep.scanSouth,
      2 => StartSessionScanStep.scanWest,
      3 => StartSessionScanStep.scanNorth,
      _ => StartSessionScanStep.review,
    };
  }

  String? get currentSeatLabel {
    return switch (currentStep) {
      StartSessionScanStep.scanEast => 'East',
      StartSessionScanStep.scanSouth => 'South',
      StartSessionScanStep.scanWest => 'West',
      StartSessionScanStep.scanNorth => 'North',
      _ => null,
    };
  }

  bool get canReview =>
      tableTagUid != null && scannedPlayerUids.length == 4;

  StartSessionScanState withTableTag(String normalizedUid) {
    return StartSessionScanState(
      tableTagUid: normalizedUid,
      scannedPlayerUids: scannedPlayerUids,
    );
  }

  StartSessionScanState withPlayerTag(String normalizedUid) {
    if (scannedPlayerUids.contains(normalizedUid)) {
      throw StateError('Duplicate player tag scanned in the same session setup.');
    }

    return StartSessionScanState(
      tableTagUid: tableTagUid,
      scannedPlayerUids: [...scannedPlayerUids, normalizedUid],
    );
  }
}
