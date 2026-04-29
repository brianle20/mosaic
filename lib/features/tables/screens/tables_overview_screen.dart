import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';
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
  });

  final String eventId;
  final String eventTitle;
  final bool scoringOpen;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;

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
            for (final table in _controller.tables)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                            label: table.nfcTagId == null
                                ? 'Tag Unbound'
                                : 'Tag Bound',
                            tone: table.nfcTagId == null
                                ? StatusChipTone.warning
                                : StatusChipTone.success,
                          ),
                          if (_controller.activeSessionsByTableId
                              .containsKey(table.id))
                            GestureDetector(
                              onTap: () => _openSessionDetail(
                                _controller
                                    .activeSessionsByTableId[table.id]!.id,
                              ),
                              child: const StatusChip(
                                label: 'Live Session',
                                tone: StatusChipTone.warning,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tableSummary(table),
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
                            child: const Text('Bind Table Tag'),
                          ),
                          if (_activeSessionFor(table) case final session?)
                            FilledButton(
                              onPressed: () => _openSessionDetail(session.id),
                              child: const Text('View Session'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

  String _tableSummary(EventTableRecord table) {
    final activeSession = _activeSessionFor(table);
    if (activeSession != null) {
      return switch (activeSession.status) {
        SessionStatus.paused => 'Session Paused',
        _ => 'Session Active',
      };
    }
    if (table.nfcTagId == null) {
      return 'Ready for Seating or Tag Binding';
    }
    return 'Scan this table tag from the event dashboard to start seating.';
  }

  TableSessionRecord? _activeSessionFor(EventTableRecord table) =>
      _controller.activeSessionsByTableId[table.id];
}
