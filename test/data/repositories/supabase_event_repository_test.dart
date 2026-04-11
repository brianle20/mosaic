import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';

void main() {
  test('repository file loads', () {
    expect(SupabaseEventRepository, isNotNull);
  });
}
