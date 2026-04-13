class LiveRunIds {
  LiveRunIds._({
    required this.scenarioSlug,
    required this.suffix,
    required this.runPrefix,
  });

  final String scenarioSlug;
  final String suffix;
  final String runPrefix;

  static LiveRunIds create(String scenarioName) {
    final scenarioSlug = scenarioName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    return LiveRunIds._(
      scenarioSlug: scenarioSlug,
      suffix: suffix,
      runPrefix: 'live_${scenarioSlug}_$suffix',
    );
  }

  String playerTagUid(String seatLabel) =>
      '${runPrefix}_${seatLabel.trim().toUpperCase()}'.toUpperCase();

  String get tableTagUid => '${runPrefix}_TABLE'.toUpperCase();
}
