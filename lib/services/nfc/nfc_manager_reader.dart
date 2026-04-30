import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mosaic/services/nfc/native_nfc_reader.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

class NfcManagerReader implements NativeNfcReader {
  NfcManagerReader({NfcManager? manager})
      : _manager = manager ?? NfcManager.instance;

  final NfcManager _manager;

  @override
  Future<NativeNfcAvailability> checkAvailability() async {
    return switch (await _manager.checkAvailability()) {
      NfcAvailability.enabled => NativeNfcAvailability.enabled,
      NfcAvailability.disabled => NativeNfcAvailability.disabled,
      NfcAvailability.unsupported => NativeNfcAvailability.unsupported,
    };
  }

  @override
  Future<Uint8List?> readUid({required String alertMessage}) async {
    final completer = Completer<Uint8List?>();
    var completed = false;

    void completeWithNull() {
      if (completed) return;
      completed = true;
      completer.complete(null);
    }

    void completeWithError(Object error, StackTrace stackTrace) {
      if (completed) return;
      completed = true;
      completer.completeError(error, stackTrace);
    }

    Future<void> stopAndCompleteWithUid(Uint8List uid) async {
      if (completed) return;
      completed = true;

      try {
        await _manager.stopSession();
      } catch (_) {
        // Keep the original successful scan result even if session cleanup fails.
      }

      completer.complete(uid);
    }

    Future<void> stopAndCompleteWithError(
      Object error,
      StackTrace stackTrace,
    ) async {
      if (completed) return;
      completed = true;

      try {
        await _manager.stopSession(errorMessageIos: error.toString());
      } catch (_) {
        // Keep the original scan error even if session cleanup fails.
      }

      completer.completeError(error, stackTrace);
    }

    await _manager.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: alertMessage,
      invalidateAfterFirstReadIos: true,
      onSessionErrorIos: (error) {
        if (error.code ==
            NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled) {
          completeWithNull();
          return;
        }

        completeWithError(
          NfcScanException(_formatIosSessionError(error)),
          StackTrace.current,
        );
      },
      onDiscovered: (tag) {
        final uid = uidBytesFromNfcManagerTag(tag);
        if (uid == null || uid.isEmpty) {
          unawaited(
            stopAndCompleteWithError(
              const NfcScanException('No NFC tag identifier was found.'),
              StackTrace.current,
            ),
          );
          return;
        }

        unawaited(stopAndCompleteWithUid(uid));
      },
    );

    return completer.future;
  }
}

String _formatIosSessionError(NfcReaderSessionErrorIos error) {
  final message = error.message.trim();
  if (message.isNotEmpty) {
    return 'NFC scan failed: $message';
  }

  return 'NFC scan failed. Try again.';
}

Uint8List? uidBytesFromNfcManagerTag(NfcTag tag) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _uidBytesFromAdapter(
        () => NfcTagAndroid.from(tag)?.id,
      ),
    TargetPlatform.iOS => _uidBytesFromAdapter(
          () => MiFareIos.from(tag)?.identifier,
        ) ??
        _uidBytesFromAdapter(
          () => Iso15693Ios.from(tag)?.identifier,
        ),
    _ => _uidBytesFromAdapter(
          () => NfcTagAndroid.from(tag)?.id,
        ) ??
        _uidBytesFromAdapter(
          () => MiFareIos.from(tag)?.identifier,
        ) ??
        _uidBytesFromAdapter(
          () => Iso15693Ios.from(tag)?.identifier,
        ),
  };
}

Uint8List? _uidBytesFromAdapter(Uint8List? Function() readUid) {
  try {
    return readUid();
  } on TypeError {
    return null;
  }
}
