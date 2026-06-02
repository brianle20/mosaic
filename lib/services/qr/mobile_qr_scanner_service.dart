import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mosaic/services/qr/qr_scanner_service.dart';

class MobileQrScannerService implements QrScannerService {
  const MobileQrScannerService();

  @override
  Future<QrScanResult?> scanPlayerCode(BuildContext context) {
    return Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _PlayerQrScannerScreen(),
      ),
    );
  }
}

class _PlayerQrScannerScreen extends StatefulWidget {
  const _PlayerQrScannerScreen();

  @override
  State<_PlayerQrScannerScreen> createState() => _PlayerQrScannerScreenState();
}

class _PlayerQrScannerScreenState extends State<_PlayerQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _didReturnResult = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_didReturnResult) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) {
        continue;
      }

      try {
        final normalizedUid = normalizeQrTagPayload(rawValue);
        _didReturnResult = true;
        Navigator.of(context).pop(
          QrScanResult(
            rawPayload: rawValue,
            normalizedUid: normalizedUid,
          ),
        );
      } on QrScanException catch (exception) {
        setState(() {
          _error = exception.message;
        });
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Player QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          if (_error case final error?)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
