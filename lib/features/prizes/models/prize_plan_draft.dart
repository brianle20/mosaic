import 'package:mosaic/data/models/prize_models.dart';

class PrizePlanDraft {
  const PrizePlanDraft({
    required this.prizeBudgetCents,
    required this.mode,
    required this.reserveFixedCents,
    required this.reservePercentageBps,
    required this.tiers,
    this.note,
  });

  final int prizeBudgetCents;
  final PrizePlanMode mode;
  final int reserveFixedCents;
  final int reservePercentageBps;
  final String? note;
  final List<PrizeTierDraftInput> tiers;

  PrizePlanDraft copyWith({
    int? prizeBudgetCents,
    PrizePlanMode? mode,
    int? reserveFixedCents,
    int? reservePercentageBps,
    String? note,
    List<PrizeTierDraftInput>? tiers,
  }) {
    return PrizePlanDraft(
      prizeBudgetCents: prizeBudgetCents ?? this.prizeBudgetCents,
      mode: mode ?? this.mode,
      reserveFixedCents: reserveFixedCents ?? this.reserveFixedCents,
      reservePercentageBps: reservePercentageBps ?? this.reservePercentageBps,
      note: note ?? this.note,
      tiers: tiers ?? this.tiers,
    );
  }

  factory PrizePlanDraft.fromDetail(PrizePlanDetail detail) {
    return PrizePlanDraft(
      prizeBudgetCents: detail.plan.prizeBudgetCents,
      mode: detail.plan.mode,
      reserveFixedCents: detail.plan.reserveFixedCents,
      reservePercentageBps: detail.plan.reservePercentageBps,
      note: detail.plan.note,
      tiers: detail.tiers
          .map(
            (tier) => PrizeTierDraftInput(
              place: tier.place,
              label: tier.label,
              percentageBps: tier.percentageBps,
              fixedAmountCents: tier.fixedAmountCents,
            ),
          )
          .toList(growable: false),
    );
  }

  String? get reserveFixedError {
    if (reserveFixedCents < 0) {
      return 'Reserve must be zero or more.';
    }

    return null;
  }

  String? get reservePercentageError {
    if (reservePercentageBps < 0 || reservePercentageBps > 10000) {
      return 'Reserve percentage must be between 0 and 10000.';
    }

    return null;
  }

  String? get generalError {
    if (mode == PrizePlanMode.none) {
      return tiers.isEmpty ? null : 'None mode cannot include prize tiers.';
    }

    if (tiers.isEmpty) {
      return 'Prize tiers are required.';
    }

    final seenPlaces = <int>{};
    for (final tier in tiers) {
      if (!seenPlaces.add(tier.place)) {
        return 'Prize tier places must be unique.';
      }
    }

    return null;
  }

  Map<int, String?> get tierErrors {
    final errors = <int, String?>{};
    for (final tier in tiers) {
      if (mode == PrizePlanMode.fixed) {
        if (tier.fixedAmountCents == null) {
          errors[tier.place] = 'Each fixed tier needs a fixed amount.';
          continue;
        }

        if (tier.fixedAmountCents! < 0) {
          errors[tier.place] = 'Fixed amounts must be zero or more.';
        }
      } else if (mode == PrizePlanMode.percentage) {
        if (tier.percentageBps == null) {
          errors[tier.place] = 'Each percentage tier needs a percentage.';
          continue;
        }

        if (tier.percentageBps! < 0 || tier.percentageBps! > 10000) {
          errors[tier.place] = 'Percentages must be between 0 and 10000.';
        }
      }
    }

    return errors;
  }

  bool get isValid {
    return reserveFixedError == null &&
        reservePercentageError == null &&
        generalError == null &&
        tierErrors.values.every((error) => error == null);
  }

  UpsertPrizePlanInput toUpsertInput({
    required String eventId,
  }) {
    return UpsertPrizePlanInput(
      eventId: eventId,
      prizeBudgetCents: prizeBudgetCents,
      mode: mode,
      reserveFixedCents: reserveFixedCents,
      reservePercentageBps: reservePercentageBps,
      note: note,
      tiers: List<PrizeTierDraftInput>.from(tiers)
        ..sort((left, right) => left.place.compareTo(right.place)),
    );
  }
}
