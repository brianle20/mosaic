import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event guest player id remains a read/cache field', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();
    final factory = _bodyAfter(source, 'factory EventGuestRecord.fromJson');
    final cacheJson = _methodBody(source, 'toCacheJson');

    expect(factory, contains("playerId: _optionalString(json, 'player_id')"));
    expect(cacheJson, contains("'player_id': playerId"));
  });

  test('event guest write payloads do not control player id', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();

    expect(_methodBody(source, 'toInsertJson'), isNot(contains("'player_id'")));
    expect(_methodBody(source, 'toUpdateJson'), isNot(contains("'player_id'")));
  });
}

String _methodBody(String source, String methodName) {
  final start = source.indexOf('Map<String, dynamic> $methodName');
  expect(start, isNonNegative, reason: '$methodName should exist');

  return _bodyFrom(source, openBraceStart: start, description: methodName);
}

String _bodyAfter(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: '$marker should exist');

  return _bodyFrom(source, openBraceStart: start, description: marker);
}

String _bodyFrom(
  String source, {
  required int openBraceStart,
  required String description,
}) {
  final openBrace = source.indexOf('{', openBraceStart);
  expect(openBrace, isNonNegative, reason: '$description should have a body');

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

  fail('$description body was not closed');
}
