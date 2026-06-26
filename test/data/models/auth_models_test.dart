import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('HostAuthUser supports email-only and phone-only users', () {
    expect(
      const HostAuthUser(
        id: 'usr_email',
        email: 'host@example.com',
      ).displayLabel,
      'host@example.com',
    );
    expect(
      const HostAuthUser(
        id: 'usr_phone',
        phoneE164: '+15551234567',
      ).displayLabel,
      '+15551234567',
    );
    expect(
      const HostAuthUser(id: 'usr_unknown').displayLabel,
      'Mosaic user',
    );
  });

  test('MosaicAccessState parses owner and normalizes legacy staff events', () {
    final access = MosaicAccessState.fromJson(const {
      'userId': 'usr_01',
      'isActive': true,
      'events': [
        {'eventId': 'evt_01', 'title': 'FV Mahjong 1', 'role': 'owner'},
        {
          'eventId': 'evt_02',
          'title': 'Qualifier',
          'role': 'qualification_scorer',
        },
        {'eventId': 'evt_03', 'title': 'Main', 'role': 'event_scorer'},
      ],
    });

    expect(access.hasApprovedAccess, isTrue);
    expect(access.ownedEvents.map((event) => event.eventId), ['evt_01']);
    expect(access.assignedEvents.map((event) => event.eventId), [
      'evt_02',
      'evt_03',
    ]);
    expect(access.roleForEvent('evt_02'), MosaicAccessRole.eventScorer);
    expect(access.canManageStaff('evt_01'), isTrue);
    expect(access.canScoreTournament('evt_02'), isTrue);
    expect(access.canScoreBonus('evt_03'), isTrue);
    expect(access.canCheckInGuests('evt_01'), isTrue);
    expect(access.canCheckInGuests('evt_02'), isFalse);
    expect(MosaicAccessRole.owner.canCheckInGuests, isTrue);
    expect(MosaicAccessRole.eventScorer.canCheckInGuests, isFalse);
    expect(MosaicAccessRole.eventScorer.canManageEvent, isFalse);
    expect(MosaicAccessRole.eventScorer.canManageStaff, isFalse);
  });

  group('MosaicAccessState serialization', () {
    test('round trips access state through json', () {
      const state = MosaicAccessState(
        userId: 'usr_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Friday Night Mahjong',
            role: MosaicAccessRole.owner,
          ),
          MosaicAccessEvent(
            eventId: 'evt_02',
            title: 'Saturday Finals',
            role: MosaicAccessRole.eventScorer,
          ),
        ],
      );

      expect(state.toJson(), {
        'userId': 'usr_01',
        'isActive': true,
        'events': [
          {
            'eventId': 'evt_01',
            'title': 'Friday Night Mahjong',
            'role': 'owner',
          },
          {
            'eventId': 'evt_02',
            'title': 'Saturday Finals',
            'role': 'event_scorer',
          },
        ],
      });
      expect(MosaicAccessState.fromJson(state.toJson()), state);
    });
  });

  group('LocalCache auth access', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and reads access for the same user', () async {
      final cache = await LocalCache.create();
      const state = MosaicAccessState(
        userId: 'usr_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Friday Night Mahjong',
            role: MosaicAccessRole.owner,
          ),
        ],
      );

      await cache.saveAccessState(state);

      expect(cache.readAccessState('usr_01'), state);
      expect(cache.readAccessState('usr_other'), isNull);
    });

    test('clears cached access', () async {
      final cache = await LocalCache.create();
      const state = MosaicAccessState(
        userId: 'usr_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Friday Night Mahjong',
            role: MosaicAccessRole.owner,
          ),
        ],
      );

      await cache.saveAccessState(state);
      await cache.clearAccessState();

      expect(cache.readAccessState('usr_01'), isNull);
    });

    test('returns null for corrupt cached json', () async {
      SharedPreferences.setMockInitialValues({
        'auth:access-state': '{not valid json',
      });
      final cache = await LocalCache.create();

      expect(cache.readAccessState('usr_01'), isNull);
    });
  });
}
