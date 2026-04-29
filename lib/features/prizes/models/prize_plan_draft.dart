import 'package:mosaic/data/models/prize_models.dart';

class PrizePlanDraft {
  const PrizePlanDraft({
    required this.mode,
    required this.tiers,
    this.note,
  });

  final PrizePlanMode mode;
  final String? note;
  final List<PrizeTierDraftInput> tiers;

  static List<PrizeTierDraftInput> defaultTiers({int count = 3}) {
    return List<PrizeTierDraftInput>.generate(
      count,
      (index) => PrizeTierDraftInput(
        place: index + 1,
        label: _ordinalLabel(index + 1),
        fixedAmountCents: 0,
      ),
      growable: false,
    );
  }

  PrizePlanDraft copyWith({
    PrizePlanMode? mode,
    String? note,
    List<PrizeTierDraftInput>? tiers,
  }) {
    return PrizePlanDraft(
      mode: mode ?? this.mode,
      note: note ?? this.note,
      tiers: tiers ?? this.tiers,
    );
  }

  factory PrizePlanDraft.fromDetail(PrizePlanDetail detail) {
    final loadedTiers = detail.tiers
        .map(
          (tier) => PrizeTierDraftInput(
            place: tier.place,
            label: _ordinalLabel(tier.place),
            percentageBps: tier.percentageBps,
            fixedAmountCents: tier.fixedAmountCents ?? 0,
          ),
        )
        .toList();
    while (loadedTiers.length < 3) {
      final place = loadedTiers.length + 1;
      loadedTiers.add(
        PrizeTierDraftInput(
          place: place,
          label: _ordinalLabel(place),
          fixedAmountCents: 0,
        ),
      );
    }

    return PrizePlanDraft(
      mode: detail.plan.mode == PrizePlanMode.none
          ? PrizePlanMode.fixed
          : detail.plan.mode,
      note: detail.plan.note,
      tiers: loadedTiers,
    );
  }

  int get totalPrizeCents => tiers.fold(
        0,
        (total, tier) =>
            total +
            ((tier.fixedAmountCents ?? 0) > 0 ? tier.fixedAmountCents! : 0),
      );

  String? get generalError {
    if (mode == PrizePlanMode.none) {
      return tiers.isEmpty ? null : 'None mode cannot include prize tiers.';
    }

    if (mode == PrizePlanMode.percentage) {
      return 'Percentage prizes are not supported for MVP.';
    }

    if (_positiveTiers.isEmpty) {
      return 'Enter at least one prize amount.';
    }

    final seenPlaces = <int>{};
    for (final tier in _positiveTiers) {
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
        if ((tier.fixedAmountCents ?? 0) < 0) {
          errors[tier.place] = 'Fixed amounts must be zero or more.';
        }
      }
    }

    return errors;
  }

  bool get isValid {
    return generalError == null &&
        tierErrors.values.every((error) => error == null);
  }

  UpsertPrizePlanInput toUpsertInput({
    required String eventId,
  }) {
    return UpsertPrizePlanInput(
      eventId: eventId,
      mode: mode,
      note: note,
      tiers: _renumberedPositiveTiers,
    );
  }

  List<PrizeTierDraftInput> get _positiveTiers =>
      tiers.where((tier) => (tier.fixedAmountCents ?? 0) > 0).toList();

  List<PrizeTierDraftInput> get _renumberedPositiveTiers {
    final sorted = List<PrizeTierDraftInput>.from(_positiveTiers)
      ..sort((left, right) => left.place.compareTo(right.place));

    return [
      for (var index = 0; index < sorted.length; index++)
        PrizeTierDraftInput(
          place: index + 1,
          label: _ordinalLabel(index + 1),
          percentageBps: sorted[index].percentageBps,
          fixedAmountCents: sorted[index].fixedAmountCents,
        ),
    ];
  }
}

String _ordinalLabel(int place) {
  final mod100 = place % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return '${place}th';
  }

  return switch (place % 10) {
    1 => '${place}st',
    2 => '${place}nd',
    3 => '${place}rd',
    _ => '${place}th',
  };
}
