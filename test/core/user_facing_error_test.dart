import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';

void main() {
  test('hides backend errors and identifiers from host-facing copy', () {
    const uuid = '01234567-89ab-cdef-0123-456789abcdef';
    final message = userFacingError(
      Exception('PostgrestException RPC failed for $uuid'),
      fallback: 'Unable to load guests.',
    );

    expect(message, 'Unable to load guests.');
    expect(message, isNot(contains(uuid)));
    expect(message, isNot(contains('RPC')));
  });
}
