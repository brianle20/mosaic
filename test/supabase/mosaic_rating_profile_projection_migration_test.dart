import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.endsWith('_mosaic_rating_profile_projection.sql'))
        .toList();

    expect(files, hasLength(1));
    migration = files.single.readAsStringSync();
  });

  test('refreshes player snapshots from official Mosaic hand history', () {
    expect(migration, contains('app_private.refresh_mosaic_player_snapshots'));
    expect(migration, contains('public.event_score_totals'));
    expect(migration, contains('public.hand_results'));
    expect(migration, contains('public.hand_settlements'));
    expect(migration, contains('declared_fan_count'));
    expect(migration, contains('mosaic_hand_ledger'));
    expect(migration, contains('tile_derived_confidence'));
    expect(migration, contains("'none'"));
    expect(migration, contains('fv mahjong 1'));
    expect(migration, contains('fv mahjong 2'));
    expect(migration, contains('south wind 3'));
  });

  test('historical profile seeds stay low-confidence without tile data', () {
    expect(migration, contains("'early_read',"));
    expect(migration, isNot(contains("'established_profile'")));
    expect(migration, isNot(contains("'developing_profile'")));
    expect(migration, contains("'none'"));
  });

  test('hand provenance is tied to the player settlement rows', () {
    expect(
      migration,
      contains('''
       settlement.payer_event_guest_id = event_player.event_guest_id
       or settlement.payee_event_guest_id = event_player.event_guest_id'''),
    );
    expect(
      migration,
      contains(
          ') filter (where settlement.id is not null) as hand_results_json'),
    );
    expect(
      migration,
      contains(
          'filter (where settlement.id is not null) as official_data_through'),
    );
  });
}
