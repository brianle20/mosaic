import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const recoveryScreens = [
    'lib/features/events/screens/event_list_screen.dart',
    'lib/features/events/screens/event_dashboard_screen.dart',
    'lib/features/guests/screens/guest_roster_screen.dart',
    'lib/features/checkin/screens/guest_detail_screen.dart',
    'lib/features/tables/screens/tables_overview_screen.dart',
    'lib/features/tables/screens/seating_assignment_screen.dart',
    'lib/features/events/screens/bonus_round_screen.dart',
    'lib/features/scoring/screens/session_detail_screen.dart',
    'lib/features/scoring/screens/event_hand_ledger_screen.dart',
    'lib/features/leaderboard/screens/leaderboard_screen.dart',
    'lib/features/prizes/screens/prize_plan_screen.dart',
    'lib/features/prizes/screens/prize_awards_screen.dart',
    'lib/features/activity/screens/activity_screen.dart',
  ];

  test('every audited cache-backed screen listens for recovery', () {
    for (final path in recoveryScreens) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('ReconnectRefreshListener'),
        reason: '$path must revalidate after offline recovery.',
      );
      final listenerStart = source.indexOf('ReconnectRefreshListener(');
      expect(
        source.substring(listenerStart),
        contains('onRefresh:'),
        reason: '$path must wire a refresh callback, not a no-op listener.',
      );
    }
  });
}
