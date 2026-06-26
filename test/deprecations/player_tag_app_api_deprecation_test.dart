import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app code no longer exposes player tag guest APIs or scans', () {
    final appFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    const disallowedTokens = <String>[
      'assignGuestTag',
      'replaceGuestTag',
      'resolveGuestByActiveTag',
      'listActiveTagAssignments',
      'scanPlayerTagForAssignment',
      'scanPlayerTagForIdentification',
      'scanPlayerTagForSessionSeat',
      'scanPlayerCode',
      'PassiveNfcService',
      'StartTableSessionInput',
      'start_table_session',
      'get_guest_tag_assignment_summary',
      'register_nfc_tag',
      'event_guest_tag_assignments',
      'eastPlayerUid',
      'southPlayerUid',
      'westPlayerUid',
      'northPlayerUid',
      'player tag assignments',
      'isEligibleForPlayerTagAssignment',
      'GuestTagLookupResult',
      'hasAssignedPlayerTag',
      'activeTagAssignment',
      'GuestTagAssignmentSummary',
      'GuestTagAssignmentStatus',
    ];

    final offenders = <String>[];
    for (final file in appFiles) {
      final source = file.readAsStringSync();
      for (final token in disallowedTokens) {
        if (source.contains(token)) {
          offenders.add('${file.path}: $token');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
