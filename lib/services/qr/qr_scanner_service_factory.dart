import 'package:mosaic/services/qr/mobile_qr_scanner_service.dart';
import 'package:mosaic/services/qr/qr_scanner_service.dart';

QrScannerService createDefaultQrScannerService() {
  return const MobileQrScannerService();
}
