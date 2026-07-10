import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/event_hand_ledger_controller.dart';
import 'package:mosaic/features/scoring/models/event_hand_ledger_view_models.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';
import 'package:mosaic/services/media/hand_photo_service.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class EventHandLedgerScreen extends StatefulWidget {
  const EventHandLedgerScreen({
    super.key,
    required this.eventId,
    required this.sessionRepository,
    this.canCorrectHands = false,
  });

  final String eventId;
  final SessionRepository sessionRepository;
  final bool canCorrectHands;

  @override
  State<EventHandLedgerScreen> createState() => _EventHandLedgerScreenState();
}

class _EventHandLedgerScreenState extends State<EventHandLedgerScreen> {
  late final EventHandLedgerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventHandLedgerController(
      sessionRepository: widget.sessionRepository,
    )
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
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

  Future<void> _openCorrection(EventHandLedgerRowViewModel row) async {
    if (!widget.canCorrectHands ||
        !row.isHandRow ||
        _controller.isLoadingCorrection) {
      return;
    }

    final target = await _controller.loadCorrectionTarget(row);
    if (!mounted || target == null) {
      return;
    }

    await Navigator.of(context).push<SessionDetailRecord>(
      MaterialPageRoute(
        builder: (_) => HandEntryScreen(
          sessionDetail: target.detail,
          guestNamesById: target.guestNamesById,
          sessionRepository: widget.sessionRepository,
          handPhotoService: ImagePickerHandPhotoService(),
          initialHand: target.hand,
        ),
      ),
    );

    if (mounted) {
      await _controller.load(widget.eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReconnectRefreshListener(
      onRefresh: () => _controller.load(widget.eventId, silent: true),
      child: Scaffold(
        appBar: AppBar(title: const Text('Hand Ledger')),
        body: AsyncBody(
          isLoading: _controller.isLoading,
          error: _controller.error,
          onRetry: () => _controller.load(widget.eventId),
          child: Column(
            children: [
              if (_controller.correctionError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    _controller.correctionError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              Expanded(
                child: _controller.rows.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: EmptyStateCard(
                            icon: Icons.receipt_long,
                            title: 'No hands recorded yet.',
                            message:
                                'Recorded hands across all tables will appear here.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _controller.rows.length,
                        itemBuilder: (context, index) {
                          final row = _controller.rows[index];
                          return _LedgerRow(
                            row: row,
                            onTap: widget.canCorrectHands &&
                                    row.isHandRow &&
                                    !_controller.isLoadingCorrection
                                ? () => _openCorrection(row)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.row, this.onTap});

  final EventHandLedgerRowViewModel row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = row.isBonusRound
        ? colorScheme.tertiaryContainer.withValues(alpha: 0.32)
        : colorScheme.surface.withValues(alpha: 0.84);
    final borderColor =
        row.isBonusRound ? colorScheme.tertiary : colorScheme.outlineVariant;
    return Opacity(
      opacity: row.isVoided ? 0.58 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: rowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              row.handLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            _LedgerMetaLine(
                              loggedTimeLabel: row.loggedTimeLabel,
                              isBonusRound: row.isBonusRound,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        row.resultSummary,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: row.hasDataIssue
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                Row(
                  children: [
                    for (var index = 0; index < row.cells.length; index++) ...[
                      if (index > 0)
                        SizedBox(
                          height: 68,
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                      Expanded(child: _LedgerCell(cell: row.cells[index])),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerMetaLine extends StatelessWidget {
  const _LedgerMetaLine({
    required this.loggedTimeLabel,
    required this.isBonusRound,
  });

  final String loggedTimeLabel;
  final bool isBonusRound;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    final bonusStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.tertiary,
          fontWeight: FontWeight.w800,
        );

    return Row(
      children: [
        Flexible(
          child: Text(
            loggedTimeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
        ),
        if (isBonusRound) ...[
          const SizedBox(width: 8),
          Icon(Icons.emoji_events, size: 13, color: colorScheme.tertiary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'Bonus round',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bonusStyle,
            ),
          ),
        ],
      ],
    );
  }
}

class _LedgerCell extends StatelessWidget {
  const _LedgerCell({required this.cell});

  final EventHandLedgerCellViewModel cell;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pointsColor = cell.pointsDelta > 0
        ? colorScheme.primary
        : cell.pointsDelta < 0
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cell.pointsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: pointsColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              cell.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
