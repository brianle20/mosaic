import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseGuestRepository tournament fields', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('creating a guest writes generated public names and open play status',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {
          expect(eventId, 'evt_01');
          expect(guestProfileId, 'prf_01');
        },
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_01',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_01',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': {
              'id': 'prf_01',
              'owner_user_id': 'usr_01',
              'display_name': 'Brian Le',
              'normalized_name': 'brian le',
              'public_display_name': 'Brian L.',
            },
          };
        },
      );

      final guest = await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Brian Le',
          normalizedName: 'brian le',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(capturedProfileInsert['display_name'], 'Brian Le');
      expect(capturedProfileInsert['public_display_name'], 'Brian L.');
      expect(capturedEventGuestInsert['display_name'], 'Brian Le');
      expect(capturedEventGuestInsert['public_display_name'], 'Brian L.');
      expect(capturedEventGuestInsert['tournament_status'], 'open_play_only');
      expect(guest.publicDisplayName, 'Brian L.');
      expect(guest.tournamentStatus, EventTournamentStatus.openPlayOnly);
    });

    test('creating a guest preserves an explicit public display name',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_02',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_02',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Alice Wong Chen',
          normalizedName: 'alice wong chen',
          publicDisplayName: 'Tournament Alice',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(
        capturedProfileInsert['public_display_name'],
        'Tournament Alice',
      );
      expect(
        capturedEventGuestInsert['public_display_name'],
        'Tournament Alice',
      );
    });

    test('generated public names collapse extra spaces and use final initial',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_03',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          return {
            'id': 'gst_03',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: '  Alice   Wong Chen  ',
          normalizedName: 'alice wong chen',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(capturedProfileInsert['public_display_name'], 'Alice C.');
    });

    test('updating tournament status targets the event guest row', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'update_event_guest_tournament_status');
          expect(params, {
            'target_event_guest_id': 'gst_01',
            'target_tournament_status': 'qualifying',
          });
          return _guestRow(
            id: 'gst_01',
            tournamentStatus: 'qualifying',
          );
        },
      );

      final guest = await repository.updateEventGuestTournamentStatus(
        eventGuestId: 'gst_01',
        status: EventTournamentStatus.qualifying,
      );

      expect(guest.id, 'gst_01');
      expect(guest.tournamentStatus, EventTournamentStatus.qualifying);
    });

    test('marking qualified does not require qualification hands', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'update_event_guest_tournament_status');
          expect(params['target_event_guest_id'], 'gst_02');
          expect(params['target_tournament_status'], 'qualified');
          return _guestRow(
            id: 'gst_02',
            tournamentStatus: 'qualified',
          );
        },
      );

      final guest = await repository.updateEventGuestTournamentStatus(
        eventGuestId: 'gst_02',
        status: EventTournamentStatus.qualified,
      );

      expect(guest.tournamentStatus, EventTournamentStatus.qualified);
    });

    test('removeGuest deletes through RPC and removes cached row', () async {
      final cache = await LocalCache.create();
      await cache.saveGuests('evt_01', [
        EventGuestRecord.fromJson({
          ..._guestRow(id: 'gst_01'),
          'display_name': 'Alice Wong',
          'normalized_name': 'alice wong',
        }),
        EventGuestRecord.fromJson({
          ..._guestRow(id: 'gst_02'),
          'display_name': 'Bob Lee',
          'normalized_name': 'bob lee',
        }),
      ]);
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'remove_event_guest');
          expect(params, {'target_event_guest_id': 'gst_01'});
          return _guestRow(id: 'gst_01');
        },
      );

      await repository.removeGuest('gst_01');

      final cachedGuests = cache.readGuests('evt_01');
      expect(cachedGuests.map((guest) => guest.id), ['gst_02']);
    });

    test('fetches qualification leaderboard from the host-only RPC', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          expect(functionName, 'get_event_qualification_leaderboard');
          expect(params, {'target_event_id': 'evt_01'});
          return const [
            {
              'event_guest_id': 'gst_01',
              'guest_profile_id': 'prf_01',
              'full_name': 'Brian Le',
              'tournament_status': 'qualified',
              'qualification_points': 0,
              'hands_played': 0,
              'wins': 0,
              'self_draw_wins': 0,
              'discard_wins': 0,
              'rank': 1,
            },
          ];
        },
      );

      final rows = await repository.fetchQualificationLeaderboard(
        eventId: 'evt_01',
      );

      expect(rows.single.fullName, 'Brian Le');
      expect(rows.single.tournamentStatus, EventTournamentStatus.qualified);
      expect(rows.single.qualificationPoints, 0);
    });
  });
}

Map<String, dynamic> _guestRow({
  required String id,
  String tournamentStatus = 'open_play_only',
}) {
  return {
    'id': id,
    'event_id': 'evt_01',
    'guest_profile_id': 'prf_01',
    'display_name': 'Brian Le',
    'normalized_name': 'brian le',
    'public_display_name': 'Brian L.',
    'tournament_status': tournamentStatus,
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
  };
}
