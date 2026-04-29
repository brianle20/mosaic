import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class TablesOverviewScreen extends StatefulWidget {
  const TablesOverviewScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.scoringOpen,
    required this.tableRepository,
    required this.sessionRepository,
    required this.guestRepository,
  });

  final String eventId;
  final String eventTitle;
  final bool scoringOpen;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final GuestRepository guestRepository;

  @override
  State<TablesOverviewScreen> createState() => _TablesOverviewScreenState();
}

class _TablesOverviewScreenState extends State<TablesOverviewScreen> {
  late final TableListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TableListController(
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
      guestRepository: widget.guestRepository,
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

  Future<void> _openAddTable() async {
    await Navigator.of(context).pushNamed(
      AppRouter.tableFormRoute,
      arguments: TableFormArgs(eventId: widget.eventId),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _openEditTable(EventTableRecord table) async {
    await Navigator.of(context).pushNamed(
      AppRouter.tableFormRoute,
      arguments: TableFormArgs(
        eventId: widget.eventId,
        initialTable: table,
      ),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _openSessionDetail(String sessionId) async {
    await Navigator.of(context).pushNamed(
      AppRouter.sessionDetailRoute,
      arguments: SessionDetailArgs(
        eventId: widget.eventId,
        sessionId: sessionId,
      ),
    );
    await _controller.load(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _openAddTable,
              icon: const Icon(Icons.table_restaurant),
              label: const Text('Add Table'),
            ),
            const SizedBox(height: 16),
            Text(
              widget.eventTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final cardData in _controller.cards) _buildTableCard(cardData),
            if (_controller.tables.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.table_restaurant,
                  title: 'No tables yet',
                  message: 'Add a table before starting live seating.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(TableOverviewCardData cardData) {
    final liveSummary = cardData.liveSummary;
    if (liveSummary != null) {
      return _buildLiveTableCard(cardData.table, liveSummary);
    }
    return _buildReadyTableCard(cardData.table);
  }

  Widget _buildLiveTableCard(
    EventTableRecord table,
    LiveTableSummary summary,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusChip(
                  label: _liveStatusLabel(summary.status),
                  tone: _liveStatusTone(summary.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 58,
              ),
              itemBuilder: (context, index) => _buildSeatCell(
                summary.seats[index],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    label: 'Progress',
                    value: summary.progressLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetric(
                    label: 'Last Result',
                    value: summary.lastHand.title,
                  ),
                ),
              ],
            ),
            if (summary.lastHand.detail case final detail?) ...[
              const SizedBox(height: 10),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _openSessionDetail(summary.sessionId),
                  child: const Text('View Session'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Table options',
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        table.nfcTagId == null ? 'Tag missing' : 'Tag bound',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit table'),
                    ),
                    const PopupMenuItem(
                      value: 'bind',
                      child: Text('Bind table tag'),
                    ),
                  ],
                  onSelected: (_) => _openEditTable(table),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCell(SeatSummary seat) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = seat.isDealer ? '${seat.windLabel} · Dealer' : seat.windLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: seat.isDealer
            ? colorScheme.secondaryContainer.withValues(alpha: 0.34)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seat.isDealer
              ? colorScheme.secondary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              seat.guestName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyTableCard(EventTableRecord table) {
    final hasTag = table.nfcTagId != null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusChip(
                  label: hasTag ? 'Ready' : 'Needs Tag',
                  tone:
                      hasTag ? StatusChipTone.success : StatusChipTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasTag
                  ? 'Scan this table from the event dashboard to start seating.'
                  : 'Bind this table tag before live seating.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => _openEditTable(table),
                  child: const Text('Edit'),
                ),
                OutlinedButton(
                  onPressed: () => _openEditTable(table),
                  child: const Text('Bind Tag'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _liveStatusLabel(SessionStatus status) {
    return switch (status) {
      SessionStatus.paused => 'Paused',
      _ => 'Active',
    };
  }

  StatusChipTone _liveStatusTone(SessionStatus status) {
    return switch (status) {
      SessionStatus.paused => StatusChipTone.warning,
      _ => StatusChipTone.info,
    };
  }
}
