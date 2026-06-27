import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event guest write payloads keep profile-owned contacts out', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();

    expect(
      _methodBody(source, 'toInsertJson'),
      isNot(contains("'phone_e164'")),
    );
    expect(
      _methodBody(source, 'toInsertJson'),
      isNot(contains("'email_lower'")),
    );
    expect(
      _methodBody(source, 'toUpdateJson'),
      isNot(contains("'phone_e164'")),
    );
    expect(
      _methodBody(source, 'toUpdateJson'),
      isNot(contains("'email_lower'")),
    );
  });

  test('event guest cache serialization is explicit about legacy contacts', () {
    final cacheSource =
        File('lib/data/local/local_cache.dart').readAsStringSync();

    expect(
      cacheSource,
      contains('guests.map((guest) => guest.toCacheJson()).toList()'),
    );
  });
}

String _methodBody(String source, String methodName) {
  final start = source.indexOf('Map<String, dynamic> $methodName');
  expect(start, isNonNegative, reason: '$methodName should exist');

  final openBrace = source.indexOf('{', start);
  expect(openBrace, isNonNegative, reason: '$methodName should have a body');

  var depth = 0;
  for (var index = openBrace; index < source.length; index += 1) {
    final char = source[index];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(openBrace, index + 1);
      }
    }
  }

  fail('$methodName body was not closed');
}
