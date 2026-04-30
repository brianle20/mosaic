import 'package:flutter/widgets.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/models/table_form_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class TableFormController extends ChangeNotifier {
  TableFormController({required TableRepository tableRepository})
      : _tableRepository = tableRepository;

  final TableRepository _tableRepository;

  bool isSubmitting = false;
  bool isBindingTag = false;
  String? submitError;
  EventTableRecord? latestTable;

  Future<EventTableRecord?> createScannedTable({
    required String eventId,
    required NfcService nfcService,
    required BuildContext context,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final scanResult = await nfcService.scanTableTag(context);
      if (scanResult == null) {
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      try {
        final existingTable = await _tableRepository.resolveTableByTag(
          eventId: eventId,
          scannedUid: scanResult.normalizedUid,
        );
        submitError =
            'That table tag is already bound to ${existingTable.label}.';
        isSubmitting = false;
        notifyListeners();
        return null;
      } on TableTagResolutionException catch (exception) {
        if (exception.failure == TableTagResolutionFailure.nonTableTag) {
          submitError = exception.message;
          isSubmitting = false;
          notifyListeners();
          return null;
        }
      }

      final existingTables = await _tableRepository.listTables(eventId);
      final nextDisplayOrder = existingTables.fold<int>(
            0,
            (current, table) =>
                table.displayOrder > current ? table.displayOrder : current,
          ) +
          1;
      final createdTable = await _tableRepository.createTable(
        CreateEventTableInput(
          eventId: eventId,
          label: 'Table $nextDisplayOrder',
          displayOrder: nextDisplayOrder,
        ),
      );
      final boundTable = await _tableRepository.bindTableTag(
        tableId: createdTable.id,
        scannedUid: scanResult.normalizedUid,
      );

      latestTable = boundTable;
      isSubmitting = false;
      notifyListeners();
      return boundTable;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  Future<EventTableRecord?> submit({
    required String eventId,
    required TableFormDraft draft,
    required int displayOrder,
    EventTableRecord? existingTable,
  }) async {
    if (!draft.isValid) {
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final savedTable = existingTable == null
          ? await _tableRepository.createTable(
              draft.toCreateInput(
                eventId: eventId,
                displayOrder: displayOrder,
              ),
            )
          : await _tableRepository.updateTable(
              draft.toUpdateInput(
                id: existingTable.id,
                eventId: eventId,
                displayOrder: displayOrder,
              ),
            );

      latestTable = savedTable;
      isSubmitting = false;
      notifyListeners();
      return savedTable;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  Future<EventTableRecord?> bindTableTag({
    required EventTableRecord table,
    required NfcService nfcService,
    required BuildContext context,
  }) async {
    isBindingTag = true;
    submitError = null;
    notifyListeners();

    try {
      final scanResult = await nfcService.scanTableTag(context);
      if (scanResult == null) {
        isBindingTag = false;
        notifyListeners();
        return null;
      }

      final updatedTable = await _tableRepository.bindTableTag(
        tableId: table.id,
        scannedUid: scanResult.normalizedUid,
      );
      latestTable = updatedTable;
      isBindingTag = false;
      notifyListeners();
      return updatedTable;
    } catch (exception) {
      submitError = exception.toString();
      isBindingTag = false;
      notifyListeners();
      return null;
    }
  }
}
