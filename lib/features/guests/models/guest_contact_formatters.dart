import 'package:flutter/services.dart';

String? normalizeUsPhoneToE164(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return null;
  }

  final nationalDigits = digits.length == 11 && digits.startsWith('1')
      ? digits.substring(1)
      : digits;
  if (nationalDigits.length != 10) {
    return null;
  }

  return '+1$nationalDigits';
}

String formatPhoneForDisplay(String? input) {
  if (input == null || input.trim().isEmpty) {
    return '';
  }

  final digits = input.replaceAll(RegExp(r'\D'), '');
  final nationalDigits = digits.length == 11 && digits.startsWith('1')
      ? digits.substring(1)
      : digits;
  if (nationalDigits.length != 10) {
    return input;
  }

  final area = nationalDigits.substring(0, 3);
  final prefix = nationalDigits.substring(3, 6);
  final line = nationalDigits.substring(6);

  return '($area) $prefix-$line';
}

class UsPhoneInputFormatter extends TextInputFormatter {
  const UsPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final nationalDigits = digits.length > 10 && digits.startsWith('1')
        ? digits.substring(1)
        : digits;
    final limitedDigits = nationalDigits.length > 10
        ? nationalDigits.substring(0, 10)
        : nationalDigits;
    final formatted = _formatPartialPhone(limitedDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPartialPhone(String digits) {
    if (digits.length <= 3) {
      return '(${digits.padRight(0)}';
    }

    if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    }

    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
}
