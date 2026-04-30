import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/nfc/native_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_service_factory.dart';

void main() {
  test('default NFC service is native', () {
    expect(createDefaultNfcService(), isA<NativeNfcService>());
  });
}
