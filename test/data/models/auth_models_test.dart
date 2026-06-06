import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';

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
  });
}
