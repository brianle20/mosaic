import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/nfc/manual_entry_nfc_service.dart';
import 'package:mosaic/services/nfc/native_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_service_factory.dart';

const _useManualNfc = bool.fromEnvironment('MOSAIC_USE_MANUAL_NFC');

void main() {
  test('default NFC service follows debug environment flag', () {
    expect(
      createDefaultNfcService(),
      _useManualNfc ? isA<ManualEntryNfcService>() : isA<NativeNfcService>(),
    );
  });

  test('debug override uses manual entry NFC service', () {
    expect(
      createDefaultNfcService(useManualEntryOverride: true),
      isA<ManualEntryNfcService>(),
    );
  });
}
