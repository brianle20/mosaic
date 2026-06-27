import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event guest parsing keeps public names event-scoped', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();
    final factory = _bodyAfter(source, 'factory EventGuestRecord.fromJson');

    expect(
      factory,
      contains(
          "publicDisplayName: _optionalString(json, 'public_display_name'),"),
    );
    expect(
      factory,
      isNot(contains('profile?.publicDisplayName')),
    );
  });

  test('event guest write payloads keep public names on event rows', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();

    expect(
      _methodBody(source, 'toInsertJson'),
      contains("'public_display_name': publicDisplayName"),
    );
    expect(
      _methodBody(source, 'toUpdateJson'),
      contains("'public_display_name': publicDisplayName"),
    );
  });

  test('public leaderboard SQL uses public display names only', () {
    final source = File(
      'supabase/migrations/'
      '20260601120000_keep_withdrawn_players_on_leaderboard.sql',
    ).readAsStringSync();
    final function = _sqlFunction(
      source,
      'create or replace function public.get_public_event_leaderboard',
    );

    expect(function, contains('public_display_name text'));
    expect(function, contains('guest.public_display_name'));
    expect(function, isNot(contains('guest.display_name')));
  });

  test('public bonus results SQL uses public display names only', () {
    final source = File(
      'supabase/migrations/20260524120000_event_ready_tournament_mvp.sql',
    ).readAsStringSync();
    final function = _sqlFunction(
      source,
      'create or replace function public.get_public_event_bonus_results',
    );

    expect(function, contains('public_display_name text'));
    expect(function, contains('guest.public_display_name'));
    expect(function, isNot(contains('guest.display_name')));
  });

  test('public standings snapshot payloads use public display names only', () {
    final source = File(
      'supabase/migrations/'
      '20260601120000_keep_withdrawn_players_on_leaderboard.sql',
    ).readAsStringSync();
    final function = _sqlFunction(
      source,
      'create or replace function '
      'app_private.build_public_event_standings_snapshot',
    );

    expect(
      function,
      contains("'publicDisplayName', leaderboard.public_display_name"),
    );
    expect(
      function,
      contains("'publicDisplayName', bonus.public_display_name"),
    );
    expect(
      function,
      contains("'publicDisplayName', finals.public_display_name"),
    );
    expect(
      function,
      contains("'publicDisplayName', timeline.public_display_name"),
    );
    expect(function, isNot(contains("'fullName'")));
    expect(function, isNot(contains("'displayName'")));
  });
}

String _methodBody(String source, String methodName) {
  final start = source.indexOf('Map<String, dynamic> $methodName');
  expect(start, isNonNegative, reason: '$methodName should exist');

  final bodyStart = source.indexOf(') {', start);
  expect(bodyStart, isNonNegative, reason: '$methodName should have a body');

  return _bodyFrom(source, openBraceStart: bodyStart, description: methodName);
}

String _bodyAfter(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: '$marker should exist');

  return _bodyFrom(source, openBraceStart: start, description: marker);
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
  expect(end, isNonNegative, reason: '$marker should close with \$\$;');

  return source.substring(start, end);
}
