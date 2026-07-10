import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
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
  bool hasUnsavedChanges = false;
  int _requestGeneration = 0;
  int _submissionGeneration = 0;
  int _draftEditGeneration = 0;
  bool _hasLoadedPlan = false;
  bool _isDisposed = false;
  String? _previewedPlanFingerprint;

  Future<void> load({bool silent = false}) async {
    if (_isDisposed || isSubmitting) {
      return;
    }
    final requestGeneration = ++_requestGeneration;
    final draftEditGeneration = _draftEditGeneration;
    final cachedPlan = await prizeRepository.readCachedPrizePlan(eventId);
    if (_isDisposed) {
      return;
    }
    final preservePreview = silent && hasPreviewedPayouts;
    List<PrizeAwardRecord>? cachedAwards;
    if (cachedPlan?.plan.status == PrizePlanStatus.locked) {
      cachedAwards = await prizeRepository.readCachedPrizeAwards(eventId);
    }
    if (_canApplyLoad(requestGeneration, draftEditGeneration) &&
        cachedPlan != null) {
      draft = PrizePlanDraft.fromDetail(cachedPlan);
      if (!preservePreview) {
        previewRows = const [];
        hasPreviewedPayouts = false;
        _previewedPlanFingerprint = null;
      }
      if (!silent || cachedPlan.plan.status == PrizePlanStatus.locked) {
        lockedAwards = cachedAwards ?? const [];
      }
      _hasLoadedPlan = true;
    }

    if (!_isCurrentRequest(requestGeneration)) {
      return;
    }

    final shouldShowLoading = !silent;
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    _notifyIfActive();

    try {
      final loaded = await prizeRepository.loadPrizePlan(
        eventId: eventId,
      );
      if (loaded != null) {
        List<PrizeAwardRecord>? loadedAwards;
        if (loaded.plan.status == PrizePlanStatus.locked) {
          loadedAwards = await prizeRepository.loadPrizeAwards(eventId);
        }
        if (_canApplyLoad(requestGeneration, draftEditGeneration)) {
          final loadedDraft = PrizePlanDraft.fromDetail(loaded);
          final previewMatches = !preservePreview ||
              _previewedPlanFingerprint == null ||
              _previewedPlanFingerprint == _draftFingerprint(loadedDraft);
          draft = loadedDraft;
          if (!previewMatches) {
            previewRows = const [];
            hasPreviewedPayouts = false;
            _previewedPlanFingerprint = null;
          }
          lockedAwards = loadedAwards ?? const [];
          _hasLoadedPlan = true;
          hasUnsavedChanges = false;
        }
      } else if (_canApplyLoad(requestGeneration, draftEditGeneration)) {
        lockedAwards = const [];
        _hasLoadedPlan = false;
        hasUnsavedChanges = false;
        previewRows = const [];
        hasPreviewedPayouts = false;
        _previewedPlanFingerprint = null;
      }
    } catch (err) {
      if (_isCurrentRequest(requestGeneration) &&
          cachedPlan == null &&
          !hasUnsavedChanges &&
          !_hasLoadedPlan &&
          previewRows.isEmpty &&
          lockedAwards.isEmpty) {
        error = userFacingError(err, fallback: 'Unable to load prizes.');
      }
    } finally {
      if (_isCurrentRequest(requestGeneration)) {
        isLoading = false;
        _notifyIfActive();
      }
    }
  }

  void setMode(PrizePlanMode mode) {
    draft = draft.copyWith(mode: mode);
    _markDraftChanged();
    hasUnsavedChanges = true;
    error = null;
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
    _markDraftChanged();
    hasUnsavedChanges = true;
    error = null;
    notifyListeners();
  }

  void setNote(String? value) {
    draft = draft.copyWith(note: value);
    _markDraftChanged();
    hasUnsavedChanges = true;
    previewRows = const [];
    hasPreviewedPayouts = false;
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
    _markDraftChanged();
    hasUnsavedChanges = true;
    previewRows = const [];
    hasPreviewedPayouts = false;
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
    _markDraftChanged();
    hasUnsavedChanges = true;
    previewRows = const [];
    hasPreviewedPayouts = false;
    notifyListeners();
  }

  Future<void> preview() async {
    if (_isDisposed) {
      return;
    }
    if (!draft.isValid) {
      error = _validationError();
      notifyListeners();
      return;
    }
    isSubmitting = true;
    error = null;
    ++_requestGeneration;
    final submissionGeneration = ++_submissionGeneration;
    final editGeneration = _draftEditGeneration;
    _notifyIfActive();

    try {
      final saved = await prizeRepository.upsertPrizePlan(
        draft.toUpsertInput(eventId: eventId),
      );
      final loadedPreview = await prizeRepository.loadPrizePreview(eventId);
      if (!_isCurrentSubmission(submissionGeneration) ||
          editGeneration != _draftEditGeneration) {
        return;
      }
      draft = PrizePlanDraft.fromDetail(saved);
      previewRows = loadedPreview;
      hasPreviewedPayouts = true;
      hasUnsavedChanges = false;
      _previewedPlanFingerprint = _draftFingerprint(draft);
    } catch (err) {
      if (_isCurrentSubmission(submissionGeneration) &&
          editGeneration == _draftEditGeneration) {
        error = userFacingError(err, fallback: 'Unable to preview prizes.');
        hasPreviewedPayouts = false;
      }
    } finally {
      if (_isCurrentSubmission(submissionGeneration)) {
        isSubmitting = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> lockAwards() async {
    if (_isDisposed) {
      return;
    }
    if (!draft.isValid) {
      error = _validationError();
      notifyListeners();
      return;
    }
    if (!hasPreviewedPayouts) {
      error = 'Preview payouts before locking awards.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    ++_requestGeneration;
    final submissionGeneration = ++_submissionGeneration;
    final editGeneration = _draftEditGeneration;
    _notifyIfActive();

    try {
      final loadedAwards = await prizeRepository.lockPrizeAwards(eventId);
      if (!_isCurrentSubmission(submissionGeneration) ||
          editGeneration != _draftEditGeneration) {
        return;
      }
      lockedAwards = loadedAwards;
      hasUnsavedChanges = false;
    } catch (err) {
      if (_isCurrentSubmission(submissionGeneration)) {
        error = userFacingError(err, fallback: 'Unable to lock prize awards.');
      }
    } finally {
      if (_isCurrentSubmission(submissionGeneration)) {
        isSubmitting = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> refreshAfterRecovery() async {
    if (_isDisposed || isSubmitting || hasUnsavedChanges) {
      return;
    }
    await load(silent: true);
  }

  void _markDraftChanged() {
    _draftEditGeneration += 1;
    previewRows = const [];
    hasPreviewedPayouts = false;
    _previewedPlanFingerprint = null;
  }

  bool _canApplyLoad(int requestGeneration, int draftEditGeneration) {
    return _isCurrentRequest(requestGeneration) &&
        draftEditGeneration == _draftEditGeneration &&
        !hasUnsavedChanges;
  }

  bool _isCurrentRequest(int requestGeneration) {
    return !_isDisposed && requestGeneration == _requestGeneration;
  }

  bool _isCurrentSubmission(int submissionGeneration) {
    return !_isDisposed && submissionGeneration == _submissionGeneration;
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  String _draftFingerprint(PrizePlanDraft value) {
    final tiers = value.tiers
        .map(
          (tier) =>
              '${tier.place}:${tier.percentageBps}:${tier.fixedAmountCents}',
        )
        .join(',');
    return '${value.mode.name}|${value.note}|$tiers';
  }

  String _validationError() {
    return draft.generalError ??
        draft.tierErrors.values.whereType<String>().first;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration += 1;
    _submissionGeneration += 1;
    super.dispose();
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
