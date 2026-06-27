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

  test('event guest parsing treats event contact columns as fallback only', () {
    final source = File('lib/data/models/guest_models.dart').readAsStringSync();
    final factory = _bodyAfter(source, 'factory EventGuestRecord.fromJson');

    expect(
      factory,
      contains(
          "phoneE164: profile?.phoneE164 ?? _optionalString(json, 'phone_e164')"),
    );
    expect(
      factory,
      contains(
          "emailLower: profile?.emailLower ?? _optionalString(json, 'email_lower')"),
    );
  });

  test('guest repository contact lookups stay profile-scoped', () {
    final source = File(
      'lib/data/repositories/supabase_guest_repository.dart',
    ).readAsStringSync();

    _expectLookupUsesGuestProfiles(
      source: source,
      lookup: ".eq('phone_e164', phoneE164)",
    );
    _expectLookupUsesGuestProfiles(
      source: source,
      lookup: ".eq('email_lower', emailLower)",
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

void _expectLookupUsesGuestProfiles({
  required String source,
  required String lookup,
}) {
  final lookupIndexes = _allIndexesOf(source, lookup);
  expect(lookupIndexes, isNotEmpty, reason: '$lookup should exist');

  for (final lookupIndex in lookupIndexes) {
    final guestProfilesIndex =
        source.lastIndexOf(".from('guest_profiles')", lookupIndex);
    final eventGuestsIndex =
        source.lastIndexOf(".from('event_guests')", lookupIndex);

    expect(
      guestProfilesIndex,
      greaterThan(eventGuestsIndex),
      reason: '$lookup should be attached to a guest_profiles query',
    );
  }
}

List<int> _allIndexesOf(String source, String pattern) {
  final indexes = <int>[];
  var searchStart = 0;
  while (searchStart < source.length) {
    final index = source.indexOf(pattern, searchStart);
    if (index < 0) {
      return indexes;
    }

    indexes.add(index);
    searchStart = index + pattern.length;
  }

  return indexes;
}
