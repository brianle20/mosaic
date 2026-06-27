import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late List<String> statements;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/'
      '20260627150000_event_guest_contact_legacy_columns.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    statements = _sqlStatements(migration);
  });

  test('migration is comment-only', () {
    expect(
      statements,
      unorderedEquals([
        'comment on column public.guest_profiles.phone_e164 is\n'
            '  \'Canonical host-scoped saved guest phone number. New guest/contact writes should target guest_profiles, not event_guests.\'',
        'comment on column public.guest_profiles.email_lower is\n'
            '  \'Canonical host-scoped saved guest email. New guest/contact writes should target guest_profiles, not event_guests.\'',
        'comment on column public.event_guests.phone_e164 is\n'
            '  \'Legacy event guest contact snapshot retained for historical fallback reads. Canonical phone contact lives on public.guest_profiles.phone_e164; do not write new app contact updates here.\'',
        'comment on column public.event_guests.email_lower is\n'
            '  \'Legacy event guest contact snapshot retained for historical fallback reads. Canonical email contact lives on public.guest_profiles.email_lower; do not write new app contact updates here.\'',
      ]),
    );
    expect(_sqlWithoutStatements(migration, statements), isEmpty);
  });

  test('guest profile contact columns are documented as canonical', () {
    expect(
      migration,
      contains('comment on column public.guest_profiles.phone_e164'),
    );
    expect(
      migration,
      contains('comment on column public.guest_profiles.email_lower'),
    );
    expect(migration, contains('Canonical host-scoped saved guest phone'));
    expect(migration, contains('Canonical host-scoped saved guest email'));
    expect(
      migration,
      contains('New guest/contact writes should target guest_profiles'),
    );
  });

  test('event guest contact columns are documented as legacy fallback', () {
    expect(
      migration,
      contains('comment on column public.event_guests.phone_e164'),
    );
    expect(
      migration,
      contains('comment on column public.event_guests.email_lower'),
    );
    expect(
      migration,
      contains('Legacy event guest contact snapshot retained for historical'),
    );
    expect(
      migration,
      contains('public.guest_profiles.phone_e164'),
    );
    expect(
      migration,
      contains('public.guest_profiles.email_lower'),
    );
    expect(
      migration,
      contains('do not write new app contact updates here'),
    );
  });
}

List<String> _sqlStatements(String sql) {
  return RegExp(
    r"comment on column [\s\S]*?';",
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
