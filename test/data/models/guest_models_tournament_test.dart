import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';

void main() {
  group('EventTournamentStatus', () {
    test('round-trips snake case JSON values on event guests', () {
      final cases = {
        'open_play_only': EventTournamentStatus.openPlayOnly,
        'qualifying': EventTournamentStatus.qualifying,
        'qualified': EventTournamentStatus.qualified,
        'withdrawn': EventTournamentStatus.withdrawn,
      };

      for (final entry in cases.entries) {
        final guest = _eventGuestJson(
          id: 'gst_${entry.key}',
          tournamentStatus: entry.key,
        );
        final record = EventGuestRecord.fromJson(guest);

        expect(record.tournamentStatus, entry.value);
        expect(record.toJson()['tournament_status'], entry.key);
      }
    });

    test('defaults missing tournament status to open play only', () {
      final record = EventGuestRecord.fromJson(
          _eventGuestJson()..remove('tournament_status'));

      expect(record.tournamentStatus, EventTournamentStatus.openPlayOnly);
      expect(record.toJson()['tournament_status'], 'open_play_only');
    });

    test('rejects unknown tournament status values', () {
      expect(
        () => EventGuestRecord.fromJson(
          _eventGuestJson(tournamentStatus: 'spectator'),
        ),
        throwsFormatException,
      );
    });
  });

  group('public display names', () {
    test('round-trips public display name on guest profiles', () {
      final profile = GuestProfileRecord.fromJson(const {
        'id': 'prf_01',
        'owner_user_id': 'usr_01',
        'display_name': 'Brian Le',
        'normalized_name': 'brian le',
        'public_display_name': 'Brian L.',
      });

      expect(profile.publicDisplayName, 'Brian L.');
      expect(profile.toJson()['public_display_name'], 'Brian L.');
    });

    test('round-trips event-specific public display name', () {
      final guest = EventGuestRecord.fromJson(
        _eventGuestJson(publicDisplayName: 'Alice C.'),
      );

      expect(guest.publicDisplayName, 'Alice C.');
      expect(guest.toJson()['public_display_name'], 'Alice C.');
    });

    test('create and update inputs serialize public display names', () {
      final createInput = CreateGuestInput(
        eventId: 'evt_01',
        displayName: 'Alice Wong Chen',
        normalizedName: 'alice wong chen',
        publicDisplayName: 'Alice C.',
        coverStatus: CoverStatus.paid,
        coverAmountCents: 2000,
        isComped: false,
      );
      final updateInput = UpdateGuestInput(
        id: 'gst_01',
        eventId: 'evt_01',
        displayName: 'Brian Le',
        normalizedName: 'brian le',
        publicDisplayName: 'Brian L.',
        coverStatus: CoverStatus.comped,
        coverAmountCents: 0,
        isComped: true,
      );

      expect(
        createInput.toInsertJson()['public_display_name'],
        'Alice C.',
      );
      expect(
        updateInput.toUpdateJson()['public_display_name'],
        'Brian L.',
      );
    });
  });
}

Map<String, dynamic> _eventGuestJson({
  String id = 'gst_01',
  String tournamentStatus = 'qualifying',
  String? publicDisplayName,
}) {
  return {
    'id': id,
    'event_id': 'evt_01',
    'guest_profile_id': 'prf_01',
    'display_name': 'Alice Wong Chen',
    'normalized_name': 'alice wong chen',
    'public_display_name': publicDisplayName,
    'tournament_status': tournamentStatus,
    'attendance_status': 'expected',
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
  };
}
