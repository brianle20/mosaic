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

    test('warns when a normalized name matches an existing guest', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');
      final warning = draft.duplicateNameWarning(
        const [
          EventGuestRecord(
            id: 'gst_01',
            eventId: 'evt_01',
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
  });
}
