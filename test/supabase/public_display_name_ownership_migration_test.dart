import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late List<String> statements;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/'
      '20260627160000_public_display_name_ownership.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    statements = _sqlStatements(migration);
  });

  test('migration is comment-only', () {
    expect(
      statements,
      unorderedEquals([
        'comment on column public.guest_profiles.public_display_name is\n'
            '  \'Canonical saved guest public alias for the host-owned guest profile. Event rows may copy or override this value for event-specific public display.\'',
        'comment on column public.event_guests.public_display_name is\n'
            '  \'Event-scoped public alias snapshot used for public event outputs. This may differ from public.guest_profiles.public_display_name for the same saved guest.\'',
        'comment on function public.default_public_display_name(text) is\n'
            '  \'Generates the default public alias from a full guest name when no explicit public display name is supplied.\'',
        'comment on function app_private.set_public_display_name() is\n'
            '  \'Trigger helper that fills blank public_display_name values from display_name on guest profile and event guest rows.\'',
      ]),
    );
    expect(_sqlWithoutStatements(migration, statements), isEmpty);
  });

  test('profile public display name is documented as canonical saved alias',
      () {
    expect(
      migration,
      contains('comment on column public.guest_profiles.public_display_name'),
    );
    expect(migration, contains('Canonical saved guest public alias'));
    expect(migration, contains('host-owned guest profile'));
  });

  test('event guest public display name is documented as event scoped', () {
    expect(
      migration,
      contains('comment on column public.event_guests.public_display_name'),
    );
    expect(migration, contains('Event-scoped public alias snapshot'));
    expect(migration, contains('public event outputs'));
  });

  test('public name defaulting helpers are documented', () {
    expect(
      migration,
      contains('comment on function public.default_public_display_name(text)'),
    );
    expect(
      migration,
      contains('comment on function app_private.set_public_display_name()'),
    );
    expect(migration, contains('Generates the default public alias'));
    expect(migration, contains('Trigger helper that fills blank'));
  });
}

List<String> _sqlStatements(String sql) {
  return RegExp(
    r"comment on (column|function) [\s\S]*?';",
    caseSensitive: false,
  )
      .allMatches(sql)
      .map((match) => match.group(0)!)
      .map((statement) => statement.substring(0, statement.length - 1).trim())
      .toList(growable: false);
}

String _sqlWithoutStatements(String sql, List<String> statements) {
  var remainder = sql;
  for (final statement in statements) {
    remainder = remainder.replaceFirst('$statement;', '');
  }

  return remainder.trim();
}
