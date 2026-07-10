import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String squished;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260709220000_filter_hand_evidence_review_queue.sql',
    );
    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    squished = migration.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('preserves review rpc access and result contract', () {
    expect(
      migration,
      contains('drop function if exists public.list_hand_evidence_review(uuid)'),
    );
    expect(migration, contains('returns table ('));
    expect(migration, contains('win_bonuses text[]'));
    expect(migration, contains('security definer'));
    expect(migration, contains('app_private.can_manage_event'));
    expect(
      migration,
      contains(
        'grant execute on function public.list_hand_evidence_review(uuid)',
      ),
    );
  });

  test('excludes voided and non-uploaded hand evidence', () {
    expect(squished, contains("hand_result.status <> 'voided'"));
    expect(squished, contains("photo.photo_upload_status = 'uploaded'"));
    expect(squished, contains("hand_result.result_type = 'win'"));
  });

  test('requires storage-backed photos', () {
    expect(
      squished,
      contains("nullif(btrim(photo.storage_bucket), '') is not null"),
    );
    expect(
      squished,
      contains("nullif(btrim(photo.storage_path), '') is not null"),
    );
  });

  test('preserves joins ordering and tile metadata', () {
    expect(migration, contains('from public.hand_photos as photo'));
    expect(migration, contains('join public.hand_results as hand_result'));
    expect(
      migration,
      contains('left join public.hand_tile_entries as tile_entry'),
    );
    expect(
      migration,
      contains('order by photo.created_at asc, photo.id asc'),
    );
    expect(migration, contains('tile_entry.review_status'));
  });
}
