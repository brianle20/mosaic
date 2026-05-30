import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/nfc/nfc_manager_reader.dart';
import 'package:mosaic/services/nfc/native_nfc_reader.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

void main() {
  test('nfc manager reader can be constructed without touching platform APIs',
      () {
    expect(() => NfcManagerReader(), returnsNormally);
  });

  group('NfcManagerReader', () {
    test('returns null when iOS NFC session is canceled by the user', () async {
      final manager = _FakeNfcManager();
      final reader = NfcManagerReader(manager: manager);

      final future = reader.readUid(alertMessage: 'Scan');
      manager.emitSessionError(
        const NfcReaderSessionErrorIos(
          code:
              NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
          message: 'User canceled',
        ),
      );

      await expectLater(future, completion(isNull));
      expect(manager.stopSessionCount, 1);
    });

    test('recovers stale native NFC session before scanning', () async {
      final manager = _FakeNfcManager(hasActiveSession: true);
      final reader = NfcManagerReader(manager: manager);

      final future = reader.readUid(alertMessage: 'Scan');
      await Future<void>.delayed(Duration.zero);
      manager.emitSessionError(
        const NfcReaderSessionErrorIos(
          code:
              NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
          message: 'User canceled',
        ),
      );

      await expectLater(future, completion(isNull));
      expect(manager.startSessionCount, 2);
      expect(manager.stopSessionCount, 2);
    });

    test('throws scan exception when another NFC scan is already active',
        () async {
      final manager = _FakeNfcManager();
      final reader = NfcManagerReader(manager: manager);

      unawaited(reader.readUid(alertMessage: 'First scan'));

      await expectLater(
        reader.readUid(alertMessage: 'Second scan'),
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'An NFC scan is already in progress. Finish or cancel it, then try again.',
          ),
        ),
      );
    });

    test('throws scan exception when iOS NFC session fails', () async {
      final manager = _FakeNfcManager();
      final reader = NfcManagerReader(manager: manager);

      final future = reader.readUid(alertMessage: 'Scan');
      manager.emitSessionError(
        const NfcReaderSessionErrorIos(
          code: NfcReaderErrorCodeIos
              .readerSessionInvalidationErrorSessionTimeout,
          message: 'Session timed out',
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'NFC scan failed: Session timed out',
          ),
        ),
      );
    });

    test('throws scan exception when iOS tag has no identifier', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final manager = _FakeNfcManager();
      final reader = NfcManagerReader(manager: manager);

      final future = reader.readUid(alertMessage: 'Scan');
      manager.emitTag(const NfcTag(data: Object()));

      await expectLater(
        future,
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'No NFC tag identifier was found.',
          ),
        ),
      );
    });
  });

  group('native NFC reader helpers', () {
    test('formats UID bytes as uppercase hex without separators', () {
      expect(
        nfcUidHexFromBytes(Uint8List.fromList([0x04, 0xa1, 0x0b, 0xff])),
        '04A10BFF',
      );
    });

    test('rejects empty UID bytes', () {
      expect(
        () => nfcUidHexFromBytes(Uint8List(0)),
        throwsA(
          isA<NfcScanException>().having(
            (exception) => exception.message,
            'message',
            'No NFC tag identifier was found.',
          ),
        ),
      );
    });

    test('formats scan exception as its user-facing message', () {
      expect(
        const NfcScanException('NFC is not available on this device.')
            .toString(),
        'NFC is not available on this device.',
      );
    });
  });
}

class _FakeNfcManager implements NfcManager {
  _FakeNfcManager({bool hasActiveSession = false})
      : _hasActiveSession = hasActiveSession;

  void Function(NfcTag tag)? _onDiscovered;
  void Function(NfcReaderSessionErrorIos error)? _onSessionErrorIos;
  bool _hasActiveSession;
  int startSessionCount = 0;
  int stopSessionCount = 0;

  @override
  Future<NfcAvailability> checkAvailability() async => NfcAvailability.enabled;

  void emitSessionError(NfcReaderSessionErrorIos error) {
    _onSessionErrorIos?.call(error);
  }

  void emitTag(NfcTag tag) {
    _onDiscovered?.call(tag);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    bool invalidateAfterFirstReadIos = true,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
    bool noPlatformSoundsAndroid = false,
  }) async {
    startSessionCount += 1;
    if (_hasActiveSession) {
      throw PlatformException(
        code: 'session_already_exists',
        message: 'Multiple sessions cannot be active at the same time.',
      );
    }

    _hasActiveSession = true;
    _onDiscovered = onDiscovered;
    _onSessionErrorIos = onSessionErrorIos;
  }

  @override
  Future<void> stopSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    stopSessionCount += 1;
    _hasActiveSession = false;
  }
}
