import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/event_hand_ledger_controller.dart';
import 'package:mosaic/features/scoring/models/event_hand_ledger_view_models.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class EventHandLedgerScreen extends StatefulWidget {
  const EventHandLedgerScreen({
    super.key,
    required this.eventId,
    required this.sessionRepository,
  });

  final String eventId;
  final SessionRepository sessionRepository;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hand Ledger')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
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
                  return _LedgerRow(row: _controller.rows[index]);
                },
              ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.row});

  final EventHandLedgerRowViewModel row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: row.isVoided ? 0.58 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
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
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.loggedTimeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
