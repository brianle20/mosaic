import 'package:meta/meta.dart';

@immutable
class ManualTagScanDraft {
  const ManualTagScanDraft({required this.rawUid});

  final String rawUid;

  String get normalizedUid {
    return rawUid.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '').toUpperCase();
  }

  bool get isValid => normalizedUid.isNotEmpty;

  String? get uidError {
    if (isValid) {
      return null;
    }

    return 'Enter a tag UID.';
  }
}
