import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/models/prize_plan_draft.dart';

class PrizePlanController extends ChangeNotifier {
  PrizePlanController({
    required this.eventId,
    required this.prizeBudgetCents,
    required this.prizeRepository,
  }) : draft = PrizePlanDraft(
          prizeBudgetCents: prizeBudgetCents,
          mode: PrizePlanMode.none,
          reserveFixedCents: 0,
          reservePercentageBps: 0,
          tiers: const [],
        );

  final String eventId;
  final int prizeBudgetCents;
  final PrizeRepository prizeRepository;

  bool isLoading = false;
  bool isSubmitting = false;
  String? error;
  PrizePlanDraft draft;
  List<PrizeAwardPreviewRow> previewRows = const [];
  List<PrizeAwardRecord> lockedAwards = const [];

  Future<void> load() async {
    final cachedPlan = await prizeRepository.readCachedPrizePlan(eventId);
    if (cachedPlan != null) {
      draft = PrizePlanDraft.fromDetail(cachedPlan);
      previewRows = await prizeRepository.readCachedPrizePreview(eventId);
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
        prizeBudgetCents: prizeBudgetCents,
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
    }
    notifyListeners();
  }

  void setReserveFixed(int value) {
    draft = draft.copyWith(reserveFixedCents: value);
    notifyListeners();
  }

  void setReservePercentage(int value) {
    draft = draft.copyWith(reservePercentageBps: value);
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
        PrizeTierDraftInput(place: nextPlace),
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
    } catch (err) {
      error = err.toString();
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
        draft.reserveFixedError ??
        draft.reservePercentageError ??
        draft.tierErrors.values.whereType<String>().first;
  }
}
