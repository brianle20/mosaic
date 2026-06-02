import 'package:flutter/material.dart';

@immutable
class QrScanResult {
  const QrScanResult({
    required this.rawPayload,
    required this.normalizedUid,
  });

  final String rawPayload;
  final String normalizedUid;
}

@immutable
class QrScanException implements Exception {
  const QrScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class QrScannerService {
  Future<QrScanResult?> scanPlayerCode(BuildContext context);
}

String normalizeQrTagPayload(String payload) {
  final trimmed = payload.trim();
  if (trimmed.isEmpty) {
    throw const QrScanException('Scanned code is empty.');
  }

  const prefix = 'mosaic:tag:';
  final uidText = _uidTextFromPayload(trimmed, prefix: prefix);
  final normalized =
      uidText.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();

  if (normalized.isEmpty) {
    throw const QrScanException('Scanned code is not a tag UID.');
  }

  return normalized;
}

String _uidTextFromPayload(String payload, {required String prefix}) {
  final lowerPayload = payload.toLowerCase();
  if (lowerPayload.startsWith(prefix)) {
    return payload.substring(prefix.length);
  }

  if (lowerPayload.startsWith('mosaic:') ||
      RegExp(r'^[a-zA-Z]+:').hasMatch(payload)) {
    throw const QrScanException('Scanned code is not a player tag.');
  }

  if (!RegExp(r'^[0-9a-fA-F\s:-]+$').hasMatch(payload)) {
    throw const QrScanException('Scanned code is not a tag UID.');
  }

  return payload;
}
