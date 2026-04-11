import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/features/tables/models/table_form_draft.dart';

void main() {
  group('TableFormDraft', () {
    test('requires a label', () {
      const draft = TableFormDraft(label: '', mode: EventTableMode.points);

      expect(draft.labelError, 'Table label is required.');
      expect(draft.isValid, isFalse);
    });

    test('is valid with a label and mode', () {
      const draft = TableFormDraft(
        label: 'Table 1',
        mode: EventTableMode.casual,
      );

      expect(draft.isValid, isTrue);
      expect(draft.labelError, isNull);
    });
  });
}
