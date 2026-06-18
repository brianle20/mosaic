String defaultPublicDisplayNameFor(String fullName) {
  final tokens = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return fullName.trim();
  }
  if (tokens.length == 1) {
    return tokens.single;
  }

  return '${tokens.first} ${tokens.last.substring(0, 1).toUpperCase()}.';
}

String resolvePublicDisplayName({
  required String fullName,
  String? publicDisplayName,
}) {
  final trimmedPublicName = publicDisplayName?.trim();
  if (trimmedPublicName != null && trimmedPublicName.isNotEmpty) {
    return trimmedPublicName;
  }

  return defaultPublicDisplayNameFor(fullName);
}
