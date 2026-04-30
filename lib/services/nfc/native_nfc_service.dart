import 'package:flutter/material.dart';
import 'package:mosaic/services/nfc/native_nfc_reader.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class NativeNfcService implements NfcService {
  const NativeNfcService({required NativeNfcReader reader}) : _reader = reader;

  final NativeNfcReader _reader;

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
    BuildContext context,
  ) async {
    return _scanOnce('Hold a player tag near your phone.');
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return _scanOnce('Hold the table tag near your phone.');
  }

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async {
    return _scanOnce('Hold the $seatLabel player tag near your phone.');
  }

  Future<TagScanResult?> _scanOnce(String alertMessage) async {
    final availability = await _reader.checkAvailability();
    switch (availability) {
      case NativeNfcAvailability.enabled:
        break;
      case NativeNfcAvailability.disabled:
        throw const NfcScanException(
          'NFC is disabled. Enable NFC in system settings, then try again.',
        );
      case NativeNfcAvailability.unsupported:
        throw const NfcScanException('NFC is not available on this device.');
    }

    final uidBytes = await _reader.readUid(alertMessage: alertMessage);
    if (uidBytes == null) {
      return null;
    }

    final uidHex = nfcUidHexFromBytes(uidBytes);
    return TagScanResult(
      rawUid: uidHex,
      normalizedUid: uidHex,
      isManualEntry: false,
    );
  }
}
