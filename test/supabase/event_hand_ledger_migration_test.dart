import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event hand ledger migration exposes newest-first cross-table rows', () {
    final migration = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('event_hand_ledger'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(migration, contains('list_event_hand_ledger'));
    expect(migration, contains('app_private.is_event_owner(target_event_id)'));
    expect(migration, contains('session_number_for_table'));
    expect(migration, contains('east_seat_index_before_hand'));
    expect(migration, contains('jsonb_agg'));
    expect(migration, contains('points_delta'));
    expect(migration, contains('order by hand_row.entered_at desc'));
    expect(
      migration,
      contains('grant execute on function public.list_event_hand_ledger(uuid)'),
    );
  });
}
