import 'package:flutter/material.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/bonus_round_controller.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/app_actions.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class BonusRoundScreen extends StatefulWidget {
  const BonusRoundScreen({
    super.key,
    required this.eventId,
    required this.finalsRepository,
    required this.tableRepository,
    required this.nfcService,
  });

  final String eventId;
  final FinalsRepository finalsRepository;
  final TableRepository tableRepository;
  final NfcService nfcService;

  @override
  State<BonusRoundScreen> createState() => _BonusRoundScreenState();
}

class _BonusRoundScreenState extends State<BonusRoundScreen> {
  late final BonusRoundController _controller;
  BonusRoundTableRole? _scanningRole;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _controller = BonusRoundController(
      finalsRepository: widget.finalsRepository,
      tableRepository: widget.tableRepository,
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
    if (mounted) setState(() {});
  }

  Future<void> _scanTable(BonusRoundTableRole role) async {
    if (_scanningRole != null || _controller.isResolvingTable) return;
    setState(() {
      _scanningRole = role;
      _scanError = null;
    });
    try {
      final result = await widget.nfcService.scanTableTag(context);
      if (!mounted || result == null) return;
      await _controller.resolveScannedTable(
        eventId: widget.eventId,
        role: role,
        normalizedUid: result.normalizedUid,
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          _scanError = userFacingError(
            exception,
            fallback: 'Unable to read that table tag.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _scanningRole = null);
    }
  }

  Future<void> _chooseTable(BonusRoundTableRole role) async {
    final table = await showModalBottomSheet<EventTableRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final readyTables = _controller.readyTables;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose ${_tableRoleTitle(role)}',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (readyTables.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.table_bar,
                      title: 'No ready tables',
                      message:
                          'Finish active play or bind an active table tag before beginning Finals.',
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: readyTables.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final readyTable = readyTables[index];
                          final isTaken = switch (role) {
                            BonusRoundTableRole.champions =>
                              _controller.redemptionTable?.id == readyTable.id,
                            BonusRoundTableRole.redemption =>
                              _controller.championsTable?.id == readyTable.id,
                          };
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: !isTaken,
                            title: Text(readyTable.label),
                            subtitle:
                                isTaken ? const Text('Already selected') : null,
                            onTap: isTaken
                                ? null
                                : () =>
                                    Navigator.of(sheetContext).pop(readyTable),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (table != null) _controller.selectTable(role: role, table: table);
  }

  Future<void> _beginFinals() async {
    final state = await _controller.beginFinals(widget.eventId);
    if (!mounted || state == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finals tables started.')),
    );
    Navigator.of(context).pop<FinalsState>(state);
  }

  @override
  Widget build(BuildContext context) {
    final setup = _controller.setup;
    final actionError = _scanError ?? _controller.actionError;
    return ReconnectRefreshListener(
      onRefresh: () => _controller.load(widget.eventId, silent: true),
      child: Scaffold(
        appBar: AppBar(title: const Text('Begin Finals')),
        body: AsyncBody(
          isLoading: _controller.isLoading,
          error: _controller.error,
          onRetry: () => _controller.load(widget.eventId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                setup.formatTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final line in setup.orderCopy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
              if (setup.cutoffTiePlayerNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppListSurface(
                  onTap: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct qualification tiebreak',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(setup.cutoffTieNamesCopy),
                      const SizedBox(height: 4),
                      const Text(
                        'This tiebreak runs before the displayed Finals assignments become final.',
                      ),
                    ],
                  ),
                ),
              ],
              if (actionError != null) ...[
                const SizedBox(height: 12),
                InlineErrorBanner(message: actionError),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('refreshFinalsPreview'),
                    onPressed: () => _controller.load(widget.eventId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Finals preview'),
                  ),
                ),
              ],
              if (_controller.championsRequired) ...[
                const SizedBox(height: 12),
                _FinalsTablePanel(
                  title: 'Table of Champions',
                  selectedTable: _controller.championsTable,
                  rows: setup.championsRows,
                  scanKey: const ValueKey('scanChampionsTable'),
                  isScanning: _scanningRole == BonusRoundTableRole.champions,
                  onScan: () => _scanTable(BonusRoundTableRole.champions),
                  onChoose: () => _chooseTable(BonusRoundTableRole.champions),
                ),
              ],
              if (setup.automaticRedemptionPlayer case final player?) ...[
                const SizedBox(height: 12),
                AppListSurface(
                  onTap: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('5th place — ${player.displayName}'),
                      const Text('Redemption winner (no table)'),
                    ],
                  ),
                ),
              ],
              if (_controller.redemptionRequired) ...[
                const SizedBox(height: 12),
                _FinalsTablePanel(
                  title: 'Table of Redemption',
                  selectedTable: _controller.redemptionTable,
                  rows: setup.redemptionRows,
                  scanKey: const ValueKey('scanRedemptionTable'),
                  isScanning: _scanningRole == BonusRoundTableRole.redemption,
                  onScan: () => _scanTable(BonusRoundTableRole.redemption),
                  onChoose: () => _chooseTable(BonusRoundTableRole.redemption),
                ),
              ],
              const SizedBox(height: 16),
              HeroActionButton(
                label: 'Begin Finals',
                icon: Icons.emoji_events,
                enabled:
                    _controller.canBeginFinals && !_controller.isSubmitting,
                isBusy: _controller.isSubmitting,
                onPressed: _beginFinals,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalsTablePanel extends StatelessWidget {
  const _FinalsTablePanel({
    required this.title,
    required this.selectedTable,
    required this.rows,
    required this.scanKey,
    required this.isScanning,
    required this.onScan,
    required this.onChoose,
  });

  final String title;
  final EventTableRecord? selectedTable;
  final List<String> rows;
  final Key scanKey;
  final bool isScanning;
  final VoidCallback onScan;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppListSurface(
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            selectedTable?.label ?? 'No table selected',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: scanKey,
                onPressed: isScanning ? null : onScan,
                icon: const Icon(Icons.nfc),
                label: Text(isScanning ? 'Scanning' : 'Scan Table'),
              ),
              OutlinedButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.table_bar),
                label: const Text('Choose Table'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(row),
            ),
        ],
      ),
    );
  }
}

String _tableRoleTitle(BonusRoundTableRole role) => switch (role) {
      BonusRoundTableRole.champions => 'Table of Champions',
      BonusRoundTableRole.redemption => 'Table of Redemption',
    };
