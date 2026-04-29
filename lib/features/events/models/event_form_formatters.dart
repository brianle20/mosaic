import 'package:flutter/services.dart';

enum MoneyInputError { invalid, negative, tooManyDecimalPlaces }

class MoneyInputParseResult {
  const MoneyInputParseResult._({this.cents, this.error});

  const MoneyInputParseResult.valid(int cents) : this._(cents: cents);

  const MoneyInputParseResult.failure(MoneyInputError error)
      : this._(error: error);

  final int? cents;
  final MoneyInputError? error;

  bool get isValid => error == null;
}

MoneyInputParseResult parseMoneyAmount(String input) {
  var amount = input.trim();
  if (amount.isEmpty) {
    return const MoneyInputParseResult.valid(0);
  }

  if (amount.startsWith(r'$')) {
    amount = amount.substring(1);
  }

  if (amount.startsWith('-')) {
    return const MoneyInputParseResult.failure(MoneyInputError.negative);
  }

  final numericPattern = RegExp(r'^\d+(?:\.\d+)?$');
  if (!numericPattern.hasMatch(amount)) {
    return const MoneyInputParseResult.failure(MoneyInputError.invalid);
  }

  final parts = amount.split('.');
  final decimalDigits = parts.length == 2 ? parts[1] : '';
  if (decimalDigits.length > 2) {
    return const MoneyInputParseResult.failure(
      MoneyInputError.tooManyDecimalPlaces,
    );
  }

  final dollars = int.parse(parts[0]);
  final cents = decimalDigits.padRight(2, '0');

  return MoneyInputParseResult.valid(dollars * 100 + int.parse(cents));
}

String formatMoneyCents(int cents) {
  final normalizedCents = cents < 0 ? 0 : cents;
  return '${normalizedCents ~/ 100}.${(normalizedCents % 100).toString().padLeft(2, '0')}';
}

class MoneyCentsInputFormatter extends TextInputFormatter {
  const MoneyCentsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();
    if (text.startsWith('-') || RegExp('[A-Za-z]').hasMatch(text)) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final cents = digits.isEmpty ? 0 : int.parse(digits);
    final formatted = formatMoneyCents(cents);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

DateTime defaultEventStartAt(DateTime now) {
  final tomorrow = now.add(const Duration(days: 1));
  final base = DateTime(
    tomorrow.year,
    tomorrow.month,
    tomorrow.day,
    tomorrow.hour,
    tomorrow.minute,
  );
  final minutesToAdd = (30 - base.minute % 30) % 30;

  return base.add(Duration(minutes: minutesToAdd));
}

String formatEventStart(DateTime startsAt) {
  final localStartsAt = startsAt.toLocal();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final weekday = weekdays[localStartsAt.weekday - 1];
  final month = months[localStartsAt.month - 1];
  final hour = localStartsAt.hour;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final minute = localStartsAt.minute.toString().padLeft(2, '0');
  final meridiem = hour < 12 ? 'AM' : 'PM';

  return '$weekday, $month ${localStartsAt.day} at $displayHour:$minute $meridiem';
}
