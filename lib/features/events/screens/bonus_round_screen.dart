import 'package:flutter/material.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/models/table_models.dart';
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
    required this.leaderboardRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.seatingRepository,
    required this.nfcService,
  });

  final String eventId;
  final LeaderboardRepository leaderboardRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final SeatingRepository seatingRepository;
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
      leaderboardRepository: widget.leaderboardRepository,
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
      seatingRepository: widget.seatingRepository,
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

  Future<void> _scanTable(BonusRoundTableRole role) async {
    if (_scanningRole != null || _controller.isResolvingTable) {
      return;
    }

    setState(() {
      _scanningRole = role;
      _scanError = null;
    });

    try {
      final result = await widget.nfcService.scanTableTag(context);
      if (!mounted || result == null) {
        return;
      }
      await _controller.resolveScannedTable(
        eventId: widget.eventId,
        role: role,
        normalizedUid: result.normalizedUid,
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          _scanError = userFacingError(exception, fallback: 'Unable to read that table tag.');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanningRole = null;
        });
      }
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
                      message: 'Bind table tags before beginning finals.',
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

    if (table != null) {
      _controller.selectTable(role: role, table: table);
    }
  }

  Future<void> _beginFinals() async {
    final created = await _controller.createBonusRound(widget.eventId);
    if (!mounted || !created) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finals seating created.')),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanningRole = _scanningRole;
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
              if (_controller.hasLiveSessions) ...[
                const InfoPanel(message: bonusRoundLiveSessionBlockedMessage),
                const SizedBox(height: 12),
              ],
              if (actionError != null) ...[
                InlineErrorBanner(message: actionError),
                const SizedBox(height: 12),
              ],
              _BonusRoundTablePanel(
                title: 'Table of Champions',
                selectedTable: _controller.championsTable,
                seatPreviews: _controller.championSeats,
                scanKey: const ValueKey('scanChampionsTable'),
                isScanning: scanningRole == BonusRoundTableRole.champions,
                onScan: () => _scanTable(BonusRoundTableRole.champions),
                onChoose: () => _chooseTable(BonusRoundTableRole.champions),
              ),
              if (_controller.redemptionRequired) ...[
                const SizedBox(height: 12),
                _BonusRoundTablePanel(
                  title: 'Table of Redemption',
                  selectedTable: _controller.redemptionTable,
                  seatPreviews: _controller.redemptionSeats,
                  scanKey: const ValueKey('scanRedemptionTable'),
                  isScanning: scanningRole == BonusRoundTableRole.redemption,
                  onScan: () => _scanTable(BonusRoundTableRole.redemption),
                  onChoose: () => _chooseTable(BonusRoundTableRole.redemption),
                ),
              ],
              const SizedBox(height: 16),
              HeroActionButton(
                label: 'Begin Finals',
                icon: Icons.emoji_events,
                enabled: _controller.canCreateBonusRound &&
                    !_controller.isSubmitting,
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

class _BonusRoundTablePanel extends StatelessWidget {
  const _BonusRoundTablePanel({
    required this.title,
    required this.selectedTable,
    required this.seatPreviews,
    required this.scanKey,
    required this.isScanning,
    required this.onScan,
    required this.onChoose,
  });

  final String title;
  final EventTableRecord? selectedTable;
  final List<BonusRoundSeatPreview> seatPreviews;
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedTable?.label ?? 'No table selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
          for (final preview in seatPreviews) _SeatPreviewRow(preview: preview),
        ],
      ),
    );
  }
}

class _SeatPreviewRow extends StatelessWidget {
  const _SeatPreviewRow({required this.preview});

  final BonusRoundSeatPreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              preview.windLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Text(
              '${preview.seedLabel} ${preview.playerName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            preview.totalPoints.toString(),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _tableRoleTitle(BonusRoundTableRole role) {
  return switch (role) {
    BonusRoundTableRole.champions => 'Table of Champions',
    BonusRoundTableRole.redemption => 'Table of Redemption',
  };
}
