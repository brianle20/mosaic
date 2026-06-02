import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/qr/qr_scanner_service.dart';

void main() {
  group('normalizeQrTagPayload', () {
    test('normalizes a raw UID payload', () {
      expect(normalizeQrTagPayload(' a1 b2-c3:d4 '), 'A1B2C3D4');
    });

    test('normalizes a prefixed Mosaic tag payload', () {
      expect(normalizeQrTagPayload('mosaic:tag:a1b2c3d4'), 'A1B2C3D4');
    });

    test('rejects an empty payload', () {
      expect(
        () => normalizeQrTagPayload('   '),
        throwsA(isA<QrScanException>()),
      );
    });

    test('rejects an unknown prefixed payload', () {
      expect(
        () => normalizeQrTagPayload('mosaic:guest:a1b2c3d4'),
        throwsA(isA<QrScanException>()),
      );
    });

    test('rejects non-Mosaic prefixed payloads', () {
      expect(
        () => normalizeQrTagPayload('xx:a1b2c3d4'),
        throwsA(isA<QrScanException>()),
      );
    });
  });
}
