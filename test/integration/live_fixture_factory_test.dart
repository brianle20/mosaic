import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/live_cleanup.dart';
import '../../integration_test/support/live_fixture_state.dart';
import '../../integration_test/support/live_test_ids.dart';

void main() {
  group('LiveRunIds', () {
    test('generates unique scenario-scoped prefixes', () {
      final first = LiveRunIds.create('golden_path');
      final second = LiveRunIds.create('golden_path');
      final other = LiveRunIds.create('rls_boundary');

      expect(first.runPrefix, startsWith('live_golden_path_'));
      expect(second.runPrefix, startsWith('live_golden_path_'));
      expect(other.runPrefix, startsWith('live_rls_boundary_'));
      expect(first.runPrefix, isNot(equals(second.runPrefix)));
      expect(first.runPrefix, isNot(equals(other.runPrefix)));
    });

    test('normalizes tag uids consistently', () {
      final ids = LiveRunIds.create('golden_path');

      expect(ids.playerTagUid('east'),
          equals(ids.playerTagUid('east').toUpperCase()));
      expect(ids.playerTagUid('east'), contains('EAST'));
      expect(ids.playerTagUid('south'), contains('SOUTH'));
      expect(ids.tableTagUid, equals(ids.tableTagUid.toUpperCase()));
      expect(ids.tableTagUid, contains('TABLE'));
    });
  });

  group('live cleanup ordering', () {
    test('deletes child rows before parent rows', () {
      final state = LiveFixtureState(eventId: 'evt_01')
        ..normalizedTagUids.addAll(<String>['TAG_A', 'TAG_B']);

      final order =
          plannedCleanupOperations(state).map((step) => step.label).toList();

      expect(
        order,
        equals(<String>[
          'guest_cover_entries',
          'prize_awards',
          'event_guest_tag_assignments',
          'table_sessions',
          'event_tables',
          'event_guests',
          'events',
          'nfc_tags',
        ]),
      );
    });
  });
}
