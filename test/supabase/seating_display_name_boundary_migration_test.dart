import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late List<String> commentStatements;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/'
      '20260627170000_seating_display_name_boundary.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    commentStatements = _commentStatements(migration);
  });

  test('migration documents host display-name boundaries', () {
    expect(
      commentStatements,
      unorderedEquals([
        'comment on function public.get_event_seating_assignments(uuid) is\n'
            '  \'Host/admin seating assignment RPC. guest_display_name returns the event guest full display name for operational seating views; public copy/share surfaces must resolve event_guests.public_display_name instead.\'',
        'comment on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid) is\n'
            '  \'Host/admin bonus-round seating generator. Returned guest_display_name values are full display names for staff seating workflows, not public aliases.\'',
        'comment on function public.start_table_of_champions_play_in(uuid, uuid) is\n'
            '  \'Host/admin table-of-champions play-in seating generator. Returned guest_display_name values are full display names for staff seating workflows, not public aliases.\'',
        'comment on function public.get_bonus_round_state(uuid) is\n'
            '  \'Host/admin bonus-round state RPC. display_name fields are full guest display names for staff operations; public standings snapshots use publicDisplayName/public_display_name instead.\'',
      ]),
    );
  });

  test('full-name host RPCs are not executable by public or anon', () {
    for (final signature in _hostFullNameRpcSignatures) {
      expect(
        migration,
        contains('revoke all on function public.$signature from public;'),
        reason: '$signature should revoke the default public execute grant',
      );
      expect(
        migration,
        contains('revoke all on function public.$signature from anon;'),
        reason: '$signature should not be callable by anonymous clients',
      );
      expect(
        migration,
        contains(
            'grant execute on function public.$signature to authenticated;'),
        reason:
            '$signature should remain available to signed-in host/staff flows',
      );
    }
  });

  test('seating RPC comments document full names as non-public output', () {
    expect(
      migration,
      contains(
          'comment on function public.get_event_seating_assignments(uuid)'),
    );
    expect(
        migration,
        contains(
            'guest_display_name returns the event guest full display name'));
    expect(migration, contains('public copy/share surfaces'));
    expect(migration, contains('event_guests.public_display_name'));
  });

  test('bonus seating RPC comments document host/admin full-name output', () {
    expect(
      migration,
      contains(
        'comment on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)',
      ),
    );
    expect(
      migration,
      contains(
          'comment on function public.start_table_of_champions_play_in(uuid, uuid)'),
    );
    expect(
        migration, contains('full display names for staff seating workflows'));
    expect(migration, contains('not public aliases'));
  });

  test('bonus state comment points public readers to public display names', () {
    expect(
      migration,
      contains('comment on function public.get_bonus_round_state(uuid)'),
    );
    expect(migration,
        contains('display_name fields are full guest display names'));
    expect(migration, contains('publicDisplayName/public_display_name'));
  });
}

const _hostFullNameRpcSignatures = [
  'get_event_seating_assignments(uuid)',
  'clear_event_seating_assignments(uuid)',
  'generate_random_seating_assignments(uuid)',
  'generate_tournament_round(uuid)',
  'start_tournament_round(uuid)',
  'generate_bonus_round_seating_assignments(uuid, uuid, uuid)',
  'start_bonus_round_sudden_death(uuid, uuid)',
  'start_table_of_champions_play_in(uuid, uuid)',
  'get_tournament_round_summary(uuid)',
  'get_bonus_round_state(uuid)',
];

List<String> _commentStatements(String sql) {
  return RegExp(
    r"comment on function [\s\S]*?';",
    caseSensitive: false,
  )
      .allMatches(sql)
      .map((match) => match.group(0)!)
      .map((statement) => statement.substring(0, statement.length - 1).trim())
      .toList(growable: false);
}
