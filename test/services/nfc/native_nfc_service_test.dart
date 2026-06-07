import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/nfc/native_nfc_reader.dart';
import 'package:mosaic/services/nfc/native_nfc_service.dart';

void main() {
  group('NativeNfcService', () {
    testWidgets('table scan returns native UID result', (tester) async {
      final reader = _FakeNativeNfcReader(
        uidBytes: Uint8List.fromList([0x04, 0xa1, 0x0b, 0xff]),
      );
      final service = NativeNfcService(reader: reader);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final result = await service.scanTableTag(context);

      expect(result?.rawUid, '04A10BFF');
      expect(result?.normalizedUid, '04A10BFF');
      expect(result?.isManualEntry, isFalse);
      expect(reader.lastAlertMessage, contains('table tag'));
    });

    testWidgets('table scan returns null when native session is cancelled',
        (tester) async {
      final reader = _FakeNativeNfcReader();
      final service = NativeNfcService(reader: reader);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final result = await service.scanTableTag(context);

      expect(result, isNull);
      expect(reader.lastAlertMessage, contains('table tag'));
    });

    testWidgets('disabled NFC throws user-facing scan exception',
        (tester) async {
      final reader = _FakeNativeNfcReader(
        availability: NativeNfcAvailability.disabled,
      );
      final service = NativeNfcService(reader: reader);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      expect(
        service.scanTableTag(context),
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'NFC is disabled. Enable NFC in system settings, then try again.',
          ),
        ),
      );
    });

    testWidgets('unsupported NFC throws user-facing scan exception',
        (tester) async {
      final reader = _FakeNativeNfcReader(
        availability: NativeNfcAvailability.unsupported,
      );
      final service = NativeNfcService(reader: reader);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      expect(
        service.scanTableTag(context),
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'NFC is not available on this device.',
          ),
        ),
      );
    });

    testWidgets('native reader exceptions propagate out of service',
        (tester) async {
      final thrown = StateError('native read failed');
      final reader = _FakeNativeNfcReader(thrown: thrown);
      final service = NativeNfcService(reader: reader);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      expect(
        service.scanTableTag(context),
        throwsA(same(thrown)),
      );
    });
  });
}

class _FakeNativeNfcReader implements NativeNfcReader {
  _FakeNativeNfcReader({
    this.availability = NativeNfcAvailability.enabled,
    this.uidBytes,
    this.thrown,
  });

  final NativeNfcAvailability availability;
  final Uint8List? uidBytes;
  final Object? thrown;
  String? lastAlertMessage;

  @override
  Future<NativeNfcAvailability> checkAvailability() async {
    return availability;
  }

  @override
  Future<Uint8List?> readUid({required String alertMessage}) async {
    lastAlertMessage = alertMessage;
    final thrown = this.thrown;
    if (thrown != null) {
      throw thrown;
    }
    return uidBytes;
  }
}
