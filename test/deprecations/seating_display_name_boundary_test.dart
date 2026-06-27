import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';

void main() {
  test('seating assignment RPC names remain host-facing full names', () {
    final assignment = SeatingAssignmentRecord.fromJson({
      'id': 'asn_1',
      'event_id': 'evt_1',
      'event_table_id': 'tbl_1',
      'table_label': 'Table 1',
      'event_guest_id': 'gst_1',
      'guest_display_name': 'Alice Wong',
      'seat_index': 0,
      'assignment_round': 3,
      'status': 'active',
    });

    expect(assignment.displayName, 'Alice Wong');
    expect(assignment.toJson(), containsPair('display_name', 'Alice Wong'));
  });

  test('copied seating assignments prefer event public names', () {
    final source = File(
      'lib/features/tables/screens/seating_assignment_screen.dart',
    ).readAsStringSync();

    expect(
      _methodBody(source, 'Future<void> _copySeatingAssignments'),
      allOf(
        contains('guest.publicName'),
        contains('publicNamesByGuestId: publicNamesByGuestId'),
      ),
    );
    expect(
      _functionBody(source, 'String _formatSeatingAssignmentsForClipboard'),
      allOf(
        contains('publicNamesByGuestId[seat.eventGuestId]'),
        isNot(contains('?? seat.displayName')),
      ),
    );
  });

  test('latest tournament seating SQL documents full-name source', () {
    final source = File(
      'supabase/migrations/'
      '20260604130000_remove_player_tag_seating_requirement.sql',
    ).readAsStringSync();
    final function = _sqlFunction(
      source,
      'create or replace function public.generate_tournament_round',
    );

    expect(function, contains('guest_display_name text'));
    expect(function, contains('guest.display_name as guest_display_name'));
    expect(function, isNot(contains('guest.public_display_name')));
  });

  test('latest bonus state SQL keeps host names out of public alias fields',
      () {
    final source = File(
      'supabase/migrations/'
      '20260615130000_table_of_champions_play_in.sql',
    ).readAsStringSync();
    final stateFunction = _sqlFunction(
      source,
      'create or replace function public.get_bonus_round_state',
    );
    final seatingFunction = _sqlFunction(
      source,
      'create or replace function public.generate_bonus_round_seating_assignments',
    );

    expect(stateFunction, contains("'display_name', scores.display_name"));
    expect(stateFunction, contains("'display_name', guest.display_name"));
    expect(stateFunction, isNot(contains('public_display_name')));
    expect(seatingFunction, contains('guest_display_name text'));
  });
}

String _methodBody(String source, String methodName) {
  final start = source.indexOf(methodName);
  expect(start, isNonNegative, reason: '$methodName should exist');
  return _bodyFrom(source, openBraceStart: start, description: methodName);
}

String _functionBody(String source, String signatureStart) {
  final start = source.indexOf(signatureStart);
  expect(start, isNonNegative, reason: '$signatureStart should exist');
  final bodyStart = source.indexOf(') {', start);
  expect(bodyStart, isNonNegative,
      reason: '$signatureStart should have a body');
  return _bodyFrom(
    source,
    openBraceStart: bodyStart,
    description: signatureStart,
  );
}

String _bodyFrom(
  String source, {
  required int openBraceStart,
  required String description,
}) {
  final openBrace = source.indexOf('{', openBraceStart);
  expect(openBrace, isNonNegative, reason: '$description should have a body');

  var depth = 0;
  for (var index = openBrace; index < source.length; index += 1) {
    final char = source[index];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(openBrace, index + 1);
      }
    }
  }

  fail('$description body was not closed');
}

String _sqlFunction(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: '$marker should exist');

  final end = source.indexOf('\n\$\$;', start);
  expect(end, isNonNegative, reason: '$marker should end with \$\$;');

  return source.substring(start, end);
}
