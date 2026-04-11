import 'package:flutter/material.dart';

@immutable
class TagScanResult {
  const TagScanResult({
    required this.rawUid,
    required this.normalizedUid,
    required this.isManualEntry,
  });

  final String rawUid;
  final String normalizedUid;
  final bool isManualEntry;
}

abstract interface class NfcService {
  Future<TagScanResult?> scanPlayerTagForAssignment(BuildContext context);
}
