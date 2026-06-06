import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';

void main() {
  group('EventRecord slugs', () {
    test('round-trips the permanent public slug', () {
      final event = EventRecord.fromJson(
        _eventJson(publicSlug: 'fv-mahjong-1'),
      );

      expect(event.publicSlug, 'fv-mahjong-1');
      expect(event.toJson()['public_slug'], 'fv-mahjong-1');
    });

    test('keeps older cached events readable before slug backfill', () {
      final event = EventRecord.fromJson(
        _eventJson()..remove('public_slug'),
      );

      expect(event.publicSlug, isNull);
      expect(event.toJson()['public_slug'], isNull);
    });
  });

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

    test('defaults missing scoring phase to tournament', () {
      final event = EventRecord.fromJson(
        _eventJson()..remove('current_scoring_phase'),
      );

      expect(event.currentScoringPhase, EventScoringPhase.tournament);
      expect(event.toJson()['current_scoring_phase'], 'tournament');
    });
  });
}

Map<String, dynamic> _eventJson({
  String currentScoringPhase = 'tournament',
  String? publicSlug = 'friday-night-mahjong',
}) {
  return {
    'id': 'evt_01',
    'owner_user_id': 'usr_01',
    'title': 'Friday Night Mahjong',
    'public_slug': publicSlug,
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
