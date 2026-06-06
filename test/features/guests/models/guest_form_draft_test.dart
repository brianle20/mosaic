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

    test('generates default public display names from full names', () {
      expect(
          GuestFormDraft.defaultPublicDisplayNameFor('Brian Le'), 'Brian L.');
      expect(
        GuestFormDraft.defaultPublicDisplayNameFor('Alice Wong Chen'),
        'Alice C.',
      );
      expect(GuestFormDraft.defaultPublicDisplayNameFor('Cher'), 'Cher');
      expect(
        GuestFormDraft.defaultPublicDisplayNameFor('  Alice   Wong   Chen  '),
        'Alice C.',
      );
    });

    test('keeps public display name generated until host edits it', () {
      final generated = const GuestFormDraft(
        displayName: 'Brian Le',
      ).withDisplayName('Alice Wong Chen');

      expect(generated.publicDisplayName, 'Alice C.');
      expect(generated.isPublicDisplayNameManuallyEdited, isFalse);

      final overridden = generated.withPublicDisplayName('Table One Alice');
      final renamed = overridden.withDisplayName('Alice Zhang');

      expect(renamed.publicDisplayName, 'Table One Alice');
      expect(renamed.isPublicDisplayNameManuallyEdited, isTrue);
    });

    test('clearing public display name returns to generated value on save', () {
      final draft = const GuestFormDraft(
        displayName: 'Brian Le',
        publicDisplayName: 'Brian',
        isPublicDisplayNameManuallyEdited: true,
      ).withPublicDisplayName('');

      final input = draft.toCreateInput(eventId: 'evt_01');

      expect(input.publicDisplayName, 'Brian L.');
    });

    test('defaults tournament qualification to prequalified', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');

      expect(draft.tournamentStatus, EventTournamentStatus.qualified);
      expect(
        draft.toCreateInput(eventId: 'evt_01').tournamentStatus,
        EventTournamentStatus.qualified,
      );
    });

    test('update input carries explicit non-qualified tournament status', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');

      final input = draft.toUpdateInput(
        id: 'gst_01',
        eventId: 'evt_01',
        tournamentStatus: EventTournamentStatus.withdrawn,
      );

      expect(input.tournamentStatus, EventTournamentStatus.withdrawn);
      expect(input.toUpdateJson()['tournament_status'], 'withdrawn');
    });

    test('plain update input omits default tournament qualification', () {
      const draft = GuestFormDraft(displayName: 'Alice Wong');

      final input = draft.toUpdateInput(
        id: 'gst_01',
        eventId: 'evt_01',
      );

      expect(input.tournamentStatus, isNull);
      expect(input.toUpdateJson(), isNot(contains('tournament_status')));
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
            tournamentStatus: EventTournamentStatus.openPlayOnly,
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
        tournamentStatus: EventTournamentStatus.openPlayOnly,
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
        tournamentStatus: EventTournamentStatus.openPlayOnly,
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
