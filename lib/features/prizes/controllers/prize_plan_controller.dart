import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/models/prize_plan_draft.dart';

class PrizePlanController extends ChangeNotifier {
  PrizePlanController({
    required this.eventId,
    required this.prizeRepository,
  }) : draft = PrizePlanDraft(
          mode: PrizePlanMode.fixed,
          tiers: PrizePlanDraft.defaultTiers(),
        );

  final String eventId;
  final PrizeRepository prizeRepository;

  bool isLoading = false;
  bool isSubmitting = false;
  String? error;
  PrizePlanDraft draft;
  List<PrizeAwardPreviewRow> previewRows = const [];
  List<PrizeAwardRecord> lockedAwards = const [];
  bool hasPreviewedPayouts = false;

  Future<void> load() async {
    final cachedPlan = await prizeRepository.readCachedPrizePlan(eventId);
    if (cachedPlan != null) {
      draft = PrizePlanDraft.fromDetail(cachedPlan);
      previewRows = const [];
      hasPreviewedPayouts = false;
      lockedAwards = cachedPlan.plan.status == PrizePlanStatus.locked
          ? await prizeRepository.readCachedPrizeAwards(eventId)
          : const [];
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loaded = await prizeRepository.loadPrizePlan(
        eventId: eventId,
      );
      if (loaded != null) {
        draft = PrizePlanDraft.fromDetail(loaded);
        if (loaded.plan.status == PrizePlanStatus.locked) {
          lockedAwards = await prizeRepository.loadPrizeAwards(eventId);
        } else {
          lockedAwards = const [];
        }
      } else {
        lockedAwards = const [];
      }
    } catch (err) {
      if (cachedPlan == null) {
        error = err.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setMode(PrizePlanMode mode) {
    draft = draft.copyWith(mode: mode);
    error = null;
    if (mode == PrizePlanMode.none) {
      previewRows = const [];
      hasPreviewedPayouts = false;
    }
    notifyListeners();
  }

  void setPaidPlaces(int count) {
    if (count < 1) {
      return;
    }

    final tiers = List<PrizeTierDraftInput>.from(draft.tiers);
    if (count < tiers.length) {
      tiers.removeRange(count, tiers.length);
    } else {
      for (var place = tiers.length + 1; place <= count; place++) {
        tiers.add(
          PrizeTierDraftInput(
            place: place,
            label: _ordinalLabel(place),
            fixedAmountCents: 0,
          ),
        );
      }
    }

    draft = draft.copyWith(
      mode: PrizePlanMode.fixed,
      tiers: tiers,
    );
    error = null;
    previewRows = const [];
    hasPreviewedPayouts = false;
    notifyListeners();
  }

  void setNote(String? value) {
    draft = draft.copyWith(note: value);
    notifyListeners();
  }

  void addTier() {
    final nextPlace = draft.tiers.isEmpty
        ? 1
        : (draft.tiers
                .map((tier) => tier.place)
                .reduce((a, b) => a > b ? a : b) +
            1);
    draft = draft.copyWith(
      tiers: [
        ...draft.tiers,
        PrizeTierDraftInput(
          place: nextPlace,
          label: _ordinalLabel(nextPlace),
          fixedAmountCents: 0,
        ),
      ],
    );
    notifyListeners();
  }

  void updateTier(
    int index, {
    int? place,
    String? label,
    int? percentageBps,
    int? fixedAmountCents,
  }) {
    final tiers = [...draft.tiers];
    final current = tiers[index];
    tiers[index] = PrizeTierDraftInput(
      place: place ?? current.place,
      label: label ?? current.label,
      percentageBps: percentageBps ?? current.percentageBps,
      fixedAmountCents: fixedAmountCents ?? current.fixedAmountCents,
    );
    draft = draft.copyWith(tiers: tiers);
    previewRows = const [];
    hasPreviewedPayouts = false;
    notifyListeners();
  }

  Future<void> preview() async {
    if (!draft.isValid) {
      error = _validationError();
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      final saved = await prizeRepository.upsertPrizePlan(
        draft.toUpsertInput(eventId: eventId),
      );
      draft = PrizePlanDraft.fromDetail(saved);
      previewRows = await prizeRepository.loadPrizePreview(eventId);
      hasPreviewedPayouts = true;
    } catch (err) {
      error = err.toString();
      hasPreviewedPayouts = false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> lockAwards() async {
    if (!draft.isValid) {
      error = _validationError();
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      lockedAwards = await prizeRepository.lockPrizeAwards(eventId);
    } catch (err) {
      error = err.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  String _validationError() {
    return draft.generalError ??
        draft.tierErrors.values.whereType<String>().first;
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
