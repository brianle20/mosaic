import 'package:mosaic/services/nfc/manual_entry_nfc_service.dart';
import 'package:mosaic/services/nfc/native_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_manager_reader.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

const _useManualNfc = bool.fromEnvironment('MOSAIC_USE_MANUAL_NFC');

NfcService createDefaultNfcService({bool? useManualEntryOverride}) {
  if (useManualEntryOverride ?? _useManualNfc) {
    return const ManualEntryNfcService();
  }

  return NativeNfcService(reader: NfcManagerReader());
}
