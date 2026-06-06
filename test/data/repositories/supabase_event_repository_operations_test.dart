import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseEventRepository operations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('startEvent returns an active event and refreshes cache', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'start_event');
          expect(params['target_event_id'], 'evt_01');
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'active',
            'checkin_open': true,
            'scoring_open': false,
            'cover_charge_cents': 2000,
            'default_ruleset_id': 'HK_STANDARD',
            'prevailing_wind': 'east',
            'row_version': 2,
          };
        },
      );

      final event = await repository.startEvent('evt_01');

      expect(event.lifecycleStatus, EventLifecycleStatus.active);
      expect(event.checkinOpen, isTrue);
      expect(event.scoringOpen, isFalse);

      final cachedEvent = cache.readEvent('evt_01');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.lifecycleStatus, EventLifecycleStatus.active);
      expect(cachedEvent.checkinOpen, isTrue);
      expect(cachedEvent.scoringOpen, isFalse);

      final cachedEvents = cache.readEvents();
      expect(cachedEvents.single.lifecycleStatus, EventLifecycleStatus.active);
    });

    test('setOperationalFlags returns updated event state and refreshes cache',
        () async {
      final cache = await LocalCache.create();
      await cache.saveEvents([
        EventRecord.fromJson(const {
          'id': 'evt_01',
          'owner_user_id': 'usr_01',
          'title': 'Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'active',
          'checkin_open': true,
          'scoring_open': false,
          'cover_charge_cents': 2000,
          'default_ruleset_id': 'HK_STANDARD',
          'prevailing_wind': 'east',
          'row_version': 2,
        }),
      ]);
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'set_event_operational_flags');
          expect(params['target_event_id'], 'evt_01');
          expect(params['target_checkin_open'], isFalse);
          expect(params['target_scoring_open'], isTrue);
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'active',
            'checkin_open': false,
            'scoring_open': true,
            'cover_charge_cents': 2000,
            'default_ruleset_id': 'HK_STANDARD',
            'prevailing_wind': 'east',
            'row_version': 3,
          };
        },
      );

      final event = await repository.setOperationalFlags(
        eventId: 'evt_01',
        checkinOpen: false,
        scoringOpen: true,
      );

      expect(event.lifecycleStatus, EventLifecycleStatus.active);
      expect(event.checkinOpen, isFalse);
      expect(event.scoringOpen, isTrue);

      final cachedEvent = cache.readEvent('evt_01');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.checkinOpen, isFalse);
      expect(cachedEvent.scoringOpen, isTrue);

      final cachedEvents = cache.readEvents();
      expect(cachedEvents.single.scoringOpen, isTrue);
    });

    test('copyEventForTesting clones setup through RPC and refreshes cache',
        () async {
      final cache = await LocalCache.create();
      await cache.saveEvents([
        EventRecord.fromJson(const {
          'id': 'evt_01',
          'owner_user_id': 'usr_01',
          'title': 'Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'finalized',
          'checkin_open': false,
          'scoring_open': false,
          'cover_charge_cents': 2000,
          'default_ruleset_id': 'HK_STANDARD',
          'prevailing_wind': 'east',
        }),
      ]);
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'copy_event_for_testing');
          expect(params['source_event_id'], 'evt_01');
          return {
            'id': 'evt_copy',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong Copy',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'created_at': '2026-05-24T12:00:00-07:00',
            'lifecycle_status': 'draft',
            'checkin_open': false,
            'scoring_open': false,
            'cover_charge_cents': 2000,
            'default_ruleset_id': 'HK_STANDARD',
            'prevailing_wind': 'east',
            'current_scoring_phase': 'tournament',
          };
        },
      );

      final copiedEvent = await repository.copyEventForTesting('evt_01');

      expect(copiedEvent.id, 'evt_copy');
      expect(copiedEvent.title, 'Friday Night Mahjong Copy');
      expect(copiedEvent.lifecycleStatus, EventLifecycleStatus.draft);
      expect(copiedEvent.checkinOpen, isFalse);
      expect(copiedEvent.scoringOpen, isFalse);
      expect(copiedEvent.currentScoringPhase, EventScoringPhase.tournament);

      final cachedEvent = cache.readEvent('evt_copy');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.lifecycleStatus, EventLifecycleStatus.draft);
      expect(cache.readEvents().map((event) => event.id), contains('evt_copy'));
    });

    test('updateEventMetadata updates draft metadata through RPC and cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'update_event_metadata');
          expect(params, {
            'target_event_id': 'evt_01',
            'event_title': 'Edited Mahjong',
            'event_description': null,
            'event_venue_name': 'Club 88',
            'event_venue_address': '123 Bamboo Ave',
            'event_timezone': 'America/Los_Angeles',
            'event_starts_at': '2026-05-30T02:00:00.000Z',
            'event_cover_charge_cents': 1500,
            'event_default_ruleset_id': 'HK_STANDARD',
          });
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Edited Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-05-30T02:00:00.000Z',
            'created_at': '2026-05-24T12:00:00-07:00',
            'lifecycle_status': 'draft',
            'checkin_open': false,
            'scoring_open': false,
            'cover_charge_cents': 1500,
            'default_ruleset_id': 'HK_STANDARD',
            'prevailing_wind': 'east',
            'current_scoring_phase': 'tournament',
            'venue_name': 'Club 88',
            'venue_address': '123 Bamboo Ave',
          };
        },
      );

      final event = await repository.updateEventMetadata(
        UpdateEventInput(
          id: 'evt_01',
          title: 'Edited Mahjong',
          timezone: 'America/Los_Angeles',
          startsAt: DateTime(2026, 5, 29, 19),
          coverChargeCents: 1500,
          venueName: 'Club 88',
          venueAddress: '123 Bamboo Ave',
        ),
      );

      expect(event.title, 'Edited Mahjong');
      expect(event.venueName, 'Club 88');
      expect(cache.readEvent('evt_01')!.title, 'Edited Mahjong');
    });
  });
}
