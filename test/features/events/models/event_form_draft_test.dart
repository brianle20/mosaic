import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';

void main() {
  group('EventFormDraft', () {
    test('requires a non-empty title', () {
      final draft = EventFormDraft(
        title: '',
        timezone: 'America/Los_Angeles',
        startsAt: DateTime(2026, 4, 24, 19),
      );

      expect(draft.titleError, 'Title is required.');
    });

    test('requires a timezone', () {
      final draft = EventFormDraft(
        title: 'Friday Night Mahjong',
        timezone: '',
        startsAt: DateTime(2026, 4, 24, 19),
      );

      expect(draft.timezoneError, 'Timezone is required.');
    });

    test('rejects a negative cover charge', () {
      final draft = EventFormDraft(
        title: 'Friday Night Mahjong',
        timezone: 'America/Los_Angeles',
        startsAt: DateTime(2026, 4, 24, 19),
        coverChargeCents: -1,
      );

      expect(draft.coverChargeError, 'Cover charge must be zero or more.');
    });
  });
}
