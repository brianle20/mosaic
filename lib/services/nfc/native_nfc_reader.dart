import 'dart:typed_data';

import 'package:meta/meta.dart';

enum NativeNfcAvailability {
  enabled,
  disabled,
  unsupported,
}

@immutable
class NfcScanException implements Exception {
  const NfcScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class NativeNfcReader {
  Future<NativeNfcAvailability> checkAvailability();

  Future<Uint8List?> readUid({
    required String alertMessage,
  });
}

String nfcUidHexFromBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const NfcScanException('No NFC tag identifier was found.');
  }

  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}
