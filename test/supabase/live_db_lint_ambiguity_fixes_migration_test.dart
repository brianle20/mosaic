import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260627232000_live_db_lint_ambiguity_fixes.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('qualifies table of champions play-in seed rank references', () {
    final functionSql = _functionSql(
      migration,
      'public.start_table_of_champions_play_in',
    ).toLowerCase();

    expect(
      functionSql,
      contains(') as candidates\n    where candidates.seed_rank <='),
    );
    expect(
      functionSql,
      contains(') as candidates\n    where candidates.seed_rank >'),
    );
    expect(functionSql, contains('order by candidates.seed_rank asc'));
    expect(functionSql, isNot(contains('\n    where seed_rank <=')));
    expect(functionSql, isNot(contains('\n    where seed_rank >')));
    expect(functionSql, isNot(contains('\n    order by seed_rank asc')));
  });

  test('qualifies add saved guests event lookup id reference', () {
    final functionSql = _functionSql(
      migration,
      'public.add_saved_guests_to_event',
    ).toLowerCase();

    expect(functionSql, contains('from public.events as event_record'));
    expect(functionSql, contains('where event_record.id = target_event_id'));
    expect(functionSql, isNot(contains('from public.events\n  where id')));
  });

  test('migration reloads the postgrest schema cache', () {
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}

String _functionSql(String source, String functionName) {
  final match = RegExp(
    'create or replace function $functionName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).firstMatch(source);

  expect(match, isNotNull, reason: '$functionName should be recreated');
  return match!.group(0)!;
}
