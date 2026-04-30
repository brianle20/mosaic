import 'package:mosaic/services/nfc/native_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_manager_reader.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

NfcService createDefaultNfcService() {
  return NativeNfcService(reader: NfcManagerReader());
}
