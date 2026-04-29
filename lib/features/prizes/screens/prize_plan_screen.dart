import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/features/prizes/controllers/prize_plan_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';
import 'package:mosaic/widgets/status_chip.dart';

class PrizePlanScreen extends StatefulWidget {
  const PrizePlanScreen({
    super.key,
    required this.eventId,
    required this.prizeRepository,
  });

  final String eventId;
  final PrizeRepository prizeRepository;

  @override
  State<PrizePlanScreen> createState() => _PrizePlanScreenState();
}

class _PrizePlanScreenState extends State<PrizePlanScreen> {
  late final PrizePlanController _controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _previewResultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = PrizePlanController(
      eventId: widget.eventId,
      prizeRepository: widget.prizeRepository,
    )
      ..addListener(_handleUpdate)
      ..load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openLockedAwards() {
    Navigator.of(context).pushNamed(
      AppRouter.prizeAwardsRoute,
      arguments: PrizeAwardsArgs(
        eventId: widget.eventId,
        guestNamesById: {
          for (final row in _controller.previewRows)
            row.eventGuestId: row.displayName,
          for (final award in _controller.lockedAwards)
            if (award.displayName case final displayName?)
              award.eventGuestId: displayName,
        },
      ),
    );
  }

  Future<void> _previewPayouts() async {
    await _controller.preview();
    if (!mounted ||
        (!_controller.hasPreviewedPayouts && _controller.error == null)) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    final previewContext = _previewResultKey.currentContext;
    if (previewContext != null) {
      if (!previewContext.mounted) {
        return;
      }
      await Scrollable.ensureVisible(
        previewContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _controller.draft;

    return Scaffold(
      appBar: AppBar(title: const Text('Prize Plan')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Total Prizes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMoneyDisplay(draft.totalPrizeCents),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text('Preview awards before locking the official payout list.'),
          if (_controller.previewRows.isEmpty &&
              _controller.lockedAwards.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Enter prize amounts when you are ready to preview payouts.',
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Paid Places',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Remove paid place',
                onPressed: draft.tiers.length > 1
                    ? () => _controller.setPaidPlaces(draft.tiers.length - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 28,
                child: Center(child: Text(draft.tiers.length.toString())),
              ),
              IconButton(
                tooltip: 'Add paid place',
                onPressed: () => _controller.setPaidPlaces(
                  draft.tiers.length + 1,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < draft.tiers.length; index++)
            _TierEditor(
              key: ValueKey('tier-$index'),
              tierIndex: index,
              tier: draft.tiers[index],
              error: draft.tierErrors[draft.tiers[index].place],
              onChanged: ({int? fixedAmountCents}) {
                _controller.updateTier(
                  index,
                  fixedAmountCents: fixedAmountCents,
                );
              },
            ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: draft.note ?? '',
            decoration: const InputDecoration(labelText: 'Note'),
            onChanged: _controller.setNote,
          ),
          if (_controller.error != null) ...[
            const SizedBox(height: 8),
            Text(_controller.error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _controller.isSubmitting ? null : _previewPayouts,
            child: const Text('Save & Preview Payouts'),
          ),
          const SizedBox(height: 12),
          if (_controller.hasPreviewedPayouts &&
              _controller.previewRows.isEmpty) ...[
            EmptyStateCard(
              key: _previewResultKey,
              icon: Icons.leaderboard,
              title: 'No scored players yet',
              message: 'Add scores before previewing payouts.',
            ),
            const SizedBox(height: 12),
          ],
          if (_controller.previewRows.isNotEmpty) ...[
            Text(
              key: _previewResultKey,
              'Lock awards only when this preview matches the standings you want to pay out.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Preview Payouts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final row in _controller.previewRows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.displayName),
                subtitle: Text(row.displayRank),
                trailing: Text(_formatMoneyDisplay(row.awardAmountCents)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _controller.isSubmitting ? null : _controller.lockAwards,
              child: const Text('Lock Prize Awards'),
            ),
          ],
          if (_controller.lockedAwards.isNotEmpty) ...[
            const SizedBox(height: 8),
            const StatusChip(
              label: 'Locked Awards Available',
              tone: StatusChipTone.success,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _openLockedAwards,
              child: const Text('View Locked Awards'),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatMoneyDisplay(int cents) => '\$${formatMoneyCents(cents)}';

class _TierEditor extends StatefulWidget {
  const _TierEditor({
    super.key,
    required this.tierIndex,
    required this.tier,
    required this.onChanged,
    this.error,
  });

  final int tierIndex;
  final PrizeTierDraftInput tier;
  final String? error;
  final void Function({int? fixedAmountCents}) onChanged;

  @override
  State<_TierEditor> createState() => _TierEditorState();
}

class _TierEditorState extends State<_TierEditor> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: formatMoneyCents(widget.tier.fixedAmountCents ?? 0),
    );
  }

  @override
  void didUpdateWidget(covariant _TierEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cents = widget.tier.fixedAmountCents ?? 0;
    if (parseMoneyAmount(_amountController.text).cents != cents) {
      _amountController.text = formatMoneyCents(cents);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.tier.label ?? widget.tier.place.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  MoneyTextFormField(
                    fieldKey: ValueKey('tier-${widget.tierIndex}-amount'),
                    controller: _amountController,
                    labelText: 'Amount',
                    onChanged: (value) {
                      final parsed = parseMoneyAmount(value);
                      if (parsed.isValid) {
                        widget.onChanged(fixedAmountCents: parsed.cents);
                      }
                    },
                  ),
                  if (widget.error != null) ...[
                    const SizedBox(height: 8),
                    Text(widget.error!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
