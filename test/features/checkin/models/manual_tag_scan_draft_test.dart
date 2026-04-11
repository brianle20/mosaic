import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/checkin/models/manual_tag_scan_draft.dart';

void main() {
  group('ManualTagScanDraft', () {
    test('rejects an empty UID', () {
      const draft = ManualTagScanDraft(rawUid: '   ');

      expect(draft.isValid, isFalse);
      expect(draft.uidError, isNotNull);
    });

    test('normalizes mixed-case and spaced UIDs', () {
      const draft = ManualTagScanDraft(rawUid: ' 04aa bb-cc ');

      expect(draft.isValid, isTrue);
      expect(draft.normalizedUid, '04AABBCC');
    });
  });
}
