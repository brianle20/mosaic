import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';

void main() {
  group('EventScoringPhase', () {
    test('round-trips scoring phases from snake case JSON values', () {
      final cases = {
        'qualification': EventScoringPhase.qualification,
        'tournament': EventScoringPhase.tournament,
        'bonus': EventScoringPhase.bonus,
      };

      for (final entry in cases.entries) {
        final event = EventRecord.fromJson(
          _eventJson(currentScoringPhase: entry.key),
        );

        expect(event.currentScoringPhase, entry.value);
        expect(event.toJson()['current_scoring_phase'], entry.key);
      }
    });

    test('defaults missing scoring phase to qualification', () {
      final event = EventRecord.fromJson(
        _eventJson()..remove('current_scoring_phase'),
      );

      expect(event.currentScoringPhase, EventScoringPhase.qualification);
      expect(event.toJson()['current_scoring_phase'], 'qualification');
    });
  });
}

Map<String, dynamic> _eventJson({
  String currentScoringPhase = 'tournament',
}) {
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
    'current_scoring_phase': currentScoringPhase,
  };
}
