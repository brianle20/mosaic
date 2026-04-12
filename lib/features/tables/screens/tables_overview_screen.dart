import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';

class TablesOverviewScreen extends StatefulWidget {
  const TablesOverviewScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.tableRepository,
    required this.sessionRepository,
  });

  final String eventId;
  final String eventTitle;
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

  Future<void> _openStartSession(EventTableRecord table) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.startSessionRoute,
      arguments: StartSessionArgs(
        eventId: widget.eventId,
        table: table,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is StartedTableSessionRecord) {
      await Navigator.of(context).pushNamed(
        AppRouter.sessionDetailRoute,
        arguments: SessionDetailArgs(
          eventId: widget.eventId,
          sessionId: result.session.id,
        ),
      );
    }
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
                          Text(table.mode.name),
                          Text(
                            table.nfcTagId == null
                                ? 'Table Tag Unbound'
                                : 'Table Tag Bound',
                          ),
                          if (_controller.activeSessionsByTableId
                              .containsKey(table.id))
                            GestureDetector(
                              onTap: () => _openSessionDetail(
                                _controller
                                    .activeSessionsByTableId[table.id]!.id,
                              ),
                              child: const Text('Session Active'),
                            ),
                        ],
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
                          if (table.mode == EventTableMode.points)
                            FilledButton(
                              onPressed: () => _openStartSession(table),
                              child: const Text('Start Session'),
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
                child: Text('No tables yet.'),
              ),
          ],
        ),
      ),
    );
  }
}
