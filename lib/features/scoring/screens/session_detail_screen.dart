import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/session_detail_controller.dart';
import 'package:mosaic/features/scoring/models/session_detail_view_models.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/status_chip.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.scoringOpen = true,
    required this.guestRepository,
    required this.sessionRepository,
    this.nfcService,
  });

  final String eventId;
  final String sessionId;
  final bool scoringOpen;
  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;
  final NfcService? nfcService;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final SessionDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SessionDetailController(
      guestRepository: widget.guestRepository,
      sessionRepository: widget.sessionRepository,
    )
      ..addListener(_handleUpdate)
      ..load(eventId: widget.eventId, sessionId: widget.sessionId);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openHandEntry({HandResultRecord? hand}) async {
    final detail = _controller.detail;
    if (detail == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<SessionDetailRecord>(
        builder: (_) => HandEntryScreen(
          sessionDetail: detail,
          guestNamesById: _controller.guestNamesById,
          guestTagAssignmentsByGuestId:
              _controller.activeTagAssignmentsByGuestId,
          sessionRepository: widget.sessionRepository,
          nfcService: widget.nfcService,
          initialHand: hand,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.load(
        eventId: widget.eventId, sessionId: widget.sessionId);
  }

  Future<void> _showEndSessionDialog() async {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();

    try {
      final shouldSubmit = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('End Session Early'),
                content: Form(
                  key: formKey,
                  child: TextFormField(
                    controller: reasonController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reason is required.';
                      }
                      return null;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('End Session'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!mounted) {
        return;
      }

      if (!shouldSubmit) {
        return;
      }

      final reason = reasonController.text.trim();
      await _controller.endSession(reason);
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _controller.detail;
    final viewModel = detail == null
        ? null
        : buildSessionDetailViewModel(
            detail: detail,
            guestNamesById: _controller.guestNamesById,
          );
    final sessionStatus = detail?.session.status;
    final canRecordHand =
        widget.scoringOpen && sessionStatus == SessionStatus.active;

    return Scaffold(
      appBar: AppBar(title: Text(viewModel?.title ?? 'Table Session')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(
          eventId: widget.eventId,
          sessionId: widget.sessionId,
        ),
        child: detail == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_controller.actionError case final actionError?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InlineErrorBanner(message: actionError),
                    ),
                  _SessionHeader(
                    viewModel: viewModel!,
                    status: detail.session.status,
                  ),
                  const SizedBox(height: 12),
                  _SessionSummarySurface(
                    viewModel: viewModel,
                    status: detail.session.status,
                    endReason: detail.session.endReason,
                    handEntryMessage: canRecordHand
                        ? null
                        : _handEntryStatusMessage(
                            detail.session.status,
                            scoringOpen: widget.scoringOpen,
                          ),
                    isSubmitting: _controller.isSubmittingOperation,
                    onRecordHand: canRecordHand ? () => _openHandEntry() : null,
                    onPause: detail.session.status == SessionStatus.active
                        ? _controller.pauseSession
                        : null,
                    onResume: detail.session.status == SessionStatus.paused
                        ? _controller.resumeSession
                        : null,
                    onEnd: detail.session.status == SessionStatus.active ||
                            detail.session.status == SessionStatus.paused
                        ? _showEndSessionDialog
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _SeatGrid(seats: viewModel.seats),
                  const SizedBox(height: 16),
                  _HandHistory(
                    detail: detail,
                    viewModel: viewModel,
                    canRecordHand: canRecordHand,
                    onRecordHand: () => _openHandEntry(),
                    onOpenHand: (hand) => _openHandEntry(hand: hand),
                  ),
                ],
              ),
      ),
    );
  }

  String _handEntryStatusMessage(
    SessionStatus status, {
    required bool scoringOpen,
  }) {
    if (!scoringOpen && status == SessionStatus.active) {
      return 'Hand entry is unavailable while scoring is paused.';
    }

    return switch (status) {
      SessionStatus.paused =>
        'Hand entry is unavailable while this session is paused.',
      SessionStatus.endedEarly =>
        'Hand entry is closed because this session ended early.',
      SessionStatus.completed =>
        'Hand entry is closed because this session is complete.',
      SessionStatus.aborted =>
        'Hand entry is unavailable because this session was aborted.',
      SessionStatus.active => '',
    };
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.viewModel,
    required this.status,
  });

  final SessionDetailViewModel viewModel;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    return AppListSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.contextLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: viewModel.statusLabel,
                tone: _statusTone(status),
              ),
              StatusChip(label: viewModel.handCountLabel),
              StatusChip(
                label: viewModel.currentEastLabel,
                tone: StatusChipTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionSummarySurface extends StatelessWidget {
  const _SessionSummarySurface({
    required this.viewModel,
    required this.status,
    required this.endReason,
    required this.handEntryMessage,
    required this.isSubmitting,
    required this.onRecordHand,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final SessionDetailViewModel viewModel;
  final SessionStatus status;
  final String? endReason;
  final String? handEntryMessage;
  final bool isSubmitting;
  final VoidCallback? onRecordHand;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final trimmedEndReason = endReason?.trim();
    return AppListSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(viewModel.progressLabel),
          if (status == SessionStatus.endedEarly &&
              trimmedEndReason != null &&
              trimmedEndReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ended early: $trimmedEndReason'),
          ],
          if (handEntryMessage case final message?
              when message.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message),
          ],
          if (onRecordHand != null ||
              onPause != null ||
              onResume != null ||
              onEnd != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onRecordHand != null)
                  FilledButton(
                    onPressed: isSubmitting ? null : onRecordHand,
                    child: const Text('Record Hand'),
                  ),
                if (onPause != null)
                  OutlinedButton(
                    onPressed: isSubmitting ? null : onPause,
                    child: const Text('Pause'),
                  ),
                if (onResume != null)
                  FilledButton(
                    onPressed: isSubmitting ? null : onResume,
                    child: const Text('Resume'),
                  ),
                if (onEnd != null)
                  OutlinedButton(
                    onPressed: isSubmitting ? null : onEnd,
                    child: const Text('End'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({required this.seats});

  final List<SessionSeatViewModel> seats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seats',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final useSingleColumn =
                constraints.maxWidth < 320 || textScale > 1.3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: seats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: useSingleColumn ? 1 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: useSingleColumn ? 112 : 96,
              ),
              itemBuilder: (context, index) {
                return _SeatTile(seat: seats[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat});

  final SessionSeatViewModel seat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: seat.isCurrentEast
            ? colorScheme.primaryContainer.withValues(alpha: 0.44)
            : colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seat.isCurrentEast
              ? colorScheme.primary.withValues(alpha: 0.28)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seat.seatLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (seat.isCurrentEast) ...[
                const SizedBox(width: 8),
                _DealerBadge(colorScheme: colorScheme),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            seat.guestName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DealerBadge extends StatelessWidget {
  const _DealerBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'Dealer',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }
}

class _HandHistory extends StatelessWidget {
  const _HandHistory({
    required this.detail,
    required this.viewModel,
    required this.canRecordHand,
    required this.onRecordHand,
    required this.onOpenHand,
  });

  final SessionDetailRecord detail;
  final SessionDetailViewModel viewModel;
  final bool canRecordHand;
  final VoidCallback onRecordHand;
  final ValueChanged<HandResultRecord> onOpenHand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hand History',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (viewModel.hands.isEmpty)
          AppListSurface(
            child: Text(viewModel.emptyHandHistoryLabel),
          )
        else
          for (final hand in viewModel.hands) ...[
            AppListSurface(
              onTap:
                  canRecordHand ? () => onOpenHand(_recordForHand(hand)) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hand.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(hand.summaryLabel),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  HandResultRecord _recordForHand(SessionHandViewModel viewModelHand) {
    return detail.hands.firstWhere((hand) => hand.id == viewModelHand.handId);
  }
}

StatusChipTone _statusTone(SessionStatus status) {
  return switch (status) {
    SessionStatus.active => StatusChipTone.success,
    SessionStatus.paused => StatusChipTone.warning,
    SessionStatus.completed => StatusChipTone.neutral,
    SessionStatus.endedEarly => StatusChipTone.warning,
    SessionStatus.aborted => StatusChipTone.danger,
  };
}
