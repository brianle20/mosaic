import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/tables/models/table_form_draft.dart';

void main() {
  group('TableFormDraft', () {
    test('requires a label', () {
      const draft = TableFormDraft(label: '');

      expect(draft.labelError, 'Table label is required.');
      expect(draft.isValid, isFalse);
    });

    test('is valid with a label', () {
      const draft = TableFormDraft(label: 'Table 1');

      expect(draft.isValid, isTrue);
      expect(draft.labelError, isNull);
    });
  });
}
