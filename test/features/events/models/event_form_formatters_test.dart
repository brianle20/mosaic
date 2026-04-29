import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';

void main() {
  group('parseMoneyAmount', () {
    test('treats blank input as zero cents', () {
      expect(parseMoneyAmount('').cents, 0);
      expect(parseMoneyAmount('   ').cents, 0);
    });

    test('parses whole dollar amounts as cents', () {
      expect(parseMoneyAmount('0').cents, 0);
      expect(parseMoneyAmount(r'$0').cents, 0);
      expect(parseMoneyAmount('15').cents, 1500);
      expect(parseMoneyAmount(r'$15').cents, 1500);
    });

    test('parses dollar and cent amounts as cents', () {
      expect(parseMoneyAmount('15.00').cents, 1500);
      expect(parseMoneyAmount(r'$15.50').cents, 1550);
      expect(parseMoneyAmount('0.99').cents, 99);
    });

    test('rejects negative values', () {
      expect(parseMoneyAmount('-1').error, MoneyInputError.negative);
    });

    test('rejects malformed values', () {
      expect(parseMoneyAmount('fifteen').error, MoneyInputError.invalid);
    });

    test('rejects more than two decimal places', () {
      expect(
        parseMoneyAmount('15.999').error,
        MoneyInputError.tooManyDecimalPlaces,
      );
    });
  });

  group('defaultEventStartAt', () {
    test('adds one day and rounds up to the next half hour', () {
      expect(
        defaultEventStartAt(DateTime(2026, 4, 29, 12, 3, 22, 5)),
        DateTime(2026, 4, 30, 12, 30),
      );
    });

    test('keeps an exact half-hour boundary after clearing smaller units', () {
      expect(
        defaultEventStartAt(DateTime(2026, 4, 29, 12, 30, 45)),
        DateTime(2026, 4, 30, 12, 30),
      );
    });

    test('rounds past the half-hour boundary to the next hour', () {
      expect(
        defaultEventStartAt(DateTime(2026, 4, 29, 12, 31, 10)),
        DateTime(2026, 4, 30, 13),
      );
    });
  });

  group('formatEventStart', () {
    test('formats evening times with weekday, month, day, and time', () {
      expect(
        formatEventStart(DateTime(2026, 4, 30, 19, 30)),
        'Thu, Apr 30 at 7:30 PM',
      );
    });

    test('formats midnight explicitly', () {
      expect(
        formatEventStart(DateTime(2026, 4, 30)),
        'Thu, Apr 30 at 12:00 AM',
      );
    });

    test('formats UTC instants in local time', () {
      final utcStartsAt = DateTime.utc(2026, 5, 1, 2, 30);

      expect(
        formatEventStart(utcStartsAt),
        formatEventStart(utcStartsAt.toLocal()),
      );
    });
  });
}
