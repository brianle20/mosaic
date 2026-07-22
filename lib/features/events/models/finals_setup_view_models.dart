import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/finals_state_models.dart';

@immutable
class FinalsSetupViewModel {
  FinalsSetupViewModel({
    required this.formatTitle,
    required List<String> orderCopy,
    required List<String> championsRows,
    required List<String> redemptionRows,
    required this.automaticRedemptionPlayer,
    required List<String> cutoffTiePlayerNames,
  })  : orderCopy = List.unmodifiable(orderCopy),
        championsRows = List.unmodifiable(championsRows),
        redemptionRows = List.unmodifiable(redemptionRows),
        cutoffTiePlayerNames = List.unmodifiable(cutoffTiePlayerNames);

  factory FinalsSetupViewModel.fromPreview(FinalsSetupPreview preview) {
    final format = preview.format;
    return FinalsSetupViewModel(
      formatTitle: switch (format) {
        FinalsFormat.championsOnly => 'Champions only',
        FinalsFormat.automaticRedemption => 'Champions with Redemption winner',
        FinalsFormat.redemptionAdvancement =>
          'Redemption advances to Champions',
        FinalsFormat.parallelFinals => 'Parallel Finals',
        null => 'Finals setup',
      },
      orderCopy: preview.orderCopy,
      championsRows: _championsRows(preview),
      redemptionRows: [
        for (final player in preview.redemptionPlayers)
          'Seed ${player.seedRank} · ${player.displayName}',
      ],
      automaticRedemptionPlayer: format == FinalsFormat.automaticRedemption &&
              preview.redemptionPlayers.isNotEmpty
          ? preview.redemptionPlayers.first
          : null,
      cutoffTiePlayerNames: [
        for (final player in preview.cutoffTiePlayers) player.displayName,
      ],
    );
  }

  final String formatTitle;
  final List<String> orderCopy;
  final List<String> championsRows;
  final List<String> redemptionRows;
  final FinalsSetupPlayer? automaticRedemptionPlayer;
  final List<String> cutoffTiePlayerNames;

  String get cutoffTieNamesCopy {
    if (cutoffTiePlayerNames.length == 2) {
      return '${cutoffTiePlayerNames.first} and ${cutoffTiePlayerNames.last}';
    }
    if (cutoffTiePlayerNames.length > 2) {
      return '${cutoffTiePlayerNames.take(cutoffTiePlayerNames.length - 1).join(', ')}, and ${cutoffTiePlayerNames.last}';
    }
    return cutoffTiePlayerNames.isEmpty ? '' : cutoffTiePlayerNames.single;
  }

  static List<String> _championsRows(FinalsSetupPreview preview) {
    switch (preview.format) {
      case FinalsFormat.redemptionAdvancement:
        return [
          for (var seed = 1; seed <= preview.directSlots; seed += 1)
            'Seed $seed — Reserved for Champions',
          if (preview.eligiblePlayerCount == 6) ...const [
            'Slot 3 — Redemption first place',
            'Slot 4 — Redemption second place',
          ] else
            'Slot 4 — Redemption winner',
        ];
      case FinalsFormat.automaticRedemption:
      case FinalsFormat.parallelFinals:
        return const ['Seeds 1-4 — Table of Champions'];
      case FinalsFormat.championsOnly:
        return const ['All eligible players — Table of Champions'];
      case null:
        return const [];
    }
  }
}
