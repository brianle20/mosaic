import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('SupabaseEventRepository tournament fields', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('updates the event scoring phase through the event mutation RPC',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'update_event_scoring_phase');
          expect(params, {
            'target_event_id': 'evt_01',
            'target_scoring_phase': 'tournament',
          });
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'active',
            'checkin_open': true,
            'scoring_open': true,
            'cover_charge_cents': 2000,
            'default_ruleset_id': 'HK_STANDARD',
            'prevailing_wind': 'east',
            'current_scoring_phase': 'tournament',
            'row_version': 4,
          };
        },
      );

      final event = await repository.updateEventScoringPhase(
        eventId: 'evt_01',
        phase: EventScoringPhase.tournament,
      );

      expect(event.currentScoringPhase, EventScoringPhase.tournament);
      expect(cache.readEvent('evt_01')!.currentScoringPhase,
          EventScoringPhase.tournament);
    });
  });
}
