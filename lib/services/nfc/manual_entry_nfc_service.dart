import 'package:flutter/material.dart';
import 'package:mosaic/features/checkin/models/manual_tag_scan_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class ManualEntryNfcService implements NfcService {
  const ManualEntryNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(BuildContext context) async {
    return _scanTag(
      context,
      title: 'Enter Tag UID',
      labelText: 'Tag UID',
    );
  }

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async {
    return _scanTag(
      context,
      title: 'Scan $seatLabel Player Tag',
      labelText: '$seatLabel Player Tag UID',
    );
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return _scanTag(
      context,
      title: 'Scan Table Tag',
      labelText: 'Table Tag UID',
    );
  }

  Future<TagScanResult?> _scanTag(
    BuildContext context, {
    required String title,
    required String labelText,
  }) async {
    final controller = TextEditingController();
    var showValidation = false;

    final result = await showDialog<TagScanResult?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final draft = ManualTagScanDraft(rawUid: controller.text);
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: labelText,
                  errorText: showValidation ? draft.uidError : null,
                ),
                onChanged: (_) {
                  if (showValidation) {
                    setState(() {});
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final currentDraft = ManualTagScanDraft(
                      rawUid: controller.text,
                    );
                    if (!currentDraft.isValid) {
                      setState(() {
                        showValidation = true;
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      TagScanResult(
                        rawUid: controller.text,
                        normalizedUid: currentDraft.normalizedUid,
                        isManualEntry: true,
                      ),
                    );
                  },
                  child: const Text('Use Tag'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }
}
