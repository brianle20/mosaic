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
  });
}
