import 'package:meta/meta.dart';
import 'package:mosaic/data/models/table_models.dart';

@immutable
class TableFormDraft {
  const TableFormDraft({
    required this.label,
    required this.mode,
  });

  final String label;
  final EventTableMode mode;

  String? get labelError {
    if (label.trim().isEmpty) {
      return 'Table label is required.';
    }

    return null;
  }

  bool get isValid => labelError == null;

  CreateEventTableInput toCreateInput({
    required String eventId,
    required int displayOrder,
  }) {
    return CreateEventTableInput(
      eventId: eventId,
      label: label.trim(),
      mode: mode,
      displayOrder: displayOrder,
    );
  }

  UpdateEventTableInput toUpdateInput({
    required String id,
    required String eventId,
    required int displayOrder,
  }) {
    return UpdateEventTableInput(
      id: id,
      eventId: eventId,
      label: label.trim(),
      mode: mode,
      displayOrder: displayOrder,
    );
  }
}
