import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/guests/models/guest_form_draft.dart';

void main() {
  group('GuestFormDraft', () {
    test('requires a display name', () {
      const draft = GuestFormDraft(displayName: '');

      expect(draft.displayNameError, 'Name is required.');
    });

    test('rejects a negative cover amount', () {
      const draft = GuestFormDraft(
        displayName: 'Alice',
        coverAmountCents: -25,
      );

      expect(draft.coverAmountError, 'Cover amount must be zero or more.');
    });

    test('normalizes US phone numbers to E.164', () {
      const draft = GuestFormDraft(
        displayName: 'Alice',
        phoneE164: '(415) 555-2671',
      );

      expect(draft.phoneError, isNull);
      expect(draft.toCreateInput(eventId: 'evt_01').phoneE164, '+14155552671');
    });

    test('rejects invalid phone numbers', () {
      const draft = GuestFormDraft(
        displayName: 'Alice',
        phoneE164: '12345',
      );

      expect(draft.phoneError, 'Enter a 10-digit phone number.');
      expect(draft.isValid, isFalse);
    });

    test('normalizes Instagram handles without the leading at sign', () {
      const draft = GuestFormDraft(
        displayName: 'Alice',
        instagramHandle: ' @Alice.Wong_ ',
      );

      expect(draft.instagramHandleError, isNull);
      expect(
        draft.toCreateInput(eventId: 'evt_01').instagramHandle,
        'alice.wong_',
      );
    });

    test('rejects invalid Instagram handles', () {
      const draft = GuestFormDraft(
        displayName: 'Alice',
        instagramHandle: '@alice-wong',
      );

      expect(
        draft.instagramHandleError,
        'Use letters, numbers, periods, or underscores, up to 30 characters.',
      );
      expect(draft.isValid, isFalse);
    });

    test('warns when a normalized name matches an existing guest', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');
      final warning = draft.duplicateNameWarning(
        const [
          EventGuestRecord(
            id: 'gst_01',
            eventId: 'evt_01',
            guestProfileId: 'prf_01',
            displayName: 'ALICE WONG',
            normalizedName: 'alice wong',
            attendanceStatus: AttendanceStatus.expected,
            coverStatus: CoverStatus.unpaid,
            coverAmountCents: 0,
            isComped: false,
            hasScoredPlay: false,
          ),
        ],
      );

      expect(warning, 'Another guest with this name already exists.');
    });

    test('returns the matching duplicate guest by normalized name', () {
      const draft = GuestFormDraft(displayName: '  Alice   Wong ');
      const existingGuest = EventGuestRecord(
        id: 'gst_01',
        eventId: 'evt_01',
        guestProfileId: 'prf_01',
        displayName: 'ALICE WONG',
        normalizedName: 'alice wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.unpaid,
        coverAmountCents: 0,
        isComped: false,
        hasScoredPlay: false,
      );

      final duplicate = draft.duplicateNameMatch(const [existingGuest]);

      expect(duplicate, same(existingGuest));
    });

    test('ignores the edited guest when matching duplicate names', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');
      const existingGuest = EventGuestRecord(
        id: 'gst_01',
        eventId: 'evt_01',
        guestProfileId: 'prf_01',
        displayName: 'Alice Wong',
        normalizedName: 'alice wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.unpaid,
        coverAmountCents: 0,
        isComped: false,
        hasScoredPlay: false,
      );

      final duplicate = draft.duplicateNameMatch(
        const [existingGuest],
        excludeGuestId: 'gst_01',
      );

      expect(duplicate, isNull);
    });
  });
}
