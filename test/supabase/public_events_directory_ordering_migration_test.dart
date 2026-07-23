import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public events directory sorts by event time, newest first', () {
    final migrationFile = File(
      'supabase/migrations/20260723095000_sort_public_events_by_event_time.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('public.get_public_events'));
    expect(
      migration,
      contains(
        'order by\n'
        '    event.starts_at desc,\n'
        '    event.title asc;',
      ),
    );
    expect(
      migration,
      isNot(contains('snapshot.updated_at desc nulls last')),
    );
  });
}
