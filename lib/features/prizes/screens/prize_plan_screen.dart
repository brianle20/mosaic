import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_plan_controller.dart';

class PrizePlanScreen extends StatefulWidget {
  const PrizePlanScreen({
    super.key,
    required this.eventId,
    required this.prizeBudgetCents,
    required this.prizeRepository,
  });

  final String eventId;
  final int prizeBudgetCents;
  final PrizeRepository prizeRepository;

  @override
  State<PrizePlanScreen> createState() => _PrizePlanScreenState();
}

class _PrizePlanScreenState extends State<PrizePlanScreen> {
  late final PrizePlanController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrizePlanController(
      eventId: widget.eventId,
      prizeBudgetCents: widget.prizeBudgetCents,
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _controller.draft;

    return Scaffold(
      appBar: AppBar(title: const Text('Prize Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Prize Budget',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${widget.prizeBudgetCents} cents'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: draft.mode == PrizePlanMode.none,
                onSelected: (_) => _controller.setMode(PrizePlanMode.none),
              ),
              ChoiceChip(
                label: const Text('Fixed'),
                selected: draft.mode == PrizePlanMode.fixed,
                onSelected: (_) => _controller.setMode(PrizePlanMode.fixed),
              ),
              ChoiceChip(
                label: const Text('Percentage'),
                selected: draft.mode == PrizePlanMode.percentage,
                onSelected: (_) =>
                    _controller.setMode(PrizePlanMode.percentage),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: draft.reserveFixedCents.toString(),
            decoration:
                const InputDecoration(labelText: 'Reserve Fixed (cents)'),
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                _controller.setReserveFixed(int.tryParse(value) ?? -1),
          ),
          if (draft.reserveFixedError != null) ...[
            const SizedBox(height: 6),
            Text(draft.reserveFixedError!),
          ],
          const SizedBox(height: 16),
          TextFormField(
            initialValue: draft.reservePercentageBps.toString(),
            decoration:
                const InputDecoration(labelText: 'Reserve Percentage (bps)'),
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                _controller.setReservePercentage(int.tryParse(value) ?? -1),
          ),
          if (draft.reservePercentageError != null) ...[
            const SizedBox(height: 6),
            Text(draft.reservePercentageError!),
          ],
          const SizedBox(height: 16),
          TextFormField(
            initialValue: draft.note ?? '',
            decoration: const InputDecoration(labelText: 'Note'),
            onChanged: _controller.setNote,
          ),
          const SizedBox(height: 16),
          if (draft.mode != PrizePlanMode.none) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tiers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _controller.addTier,
                  child: const Text('Add Tier'),
                ),
              ],
            ),
            for (var index = 0; index < draft.tiers.length; index++)
              _TierEditor(
                key: ValueKey('tier-$index'),
                tierIndex: index,
                tier: draft.tiers[index],
                mode: draft.mode,
                error: draft.tierErrors[draft.tiers[index].place],
                onChanged: ({
                  int? place,
                  String? label,
                  int? percentageBps,
                  int? fixedAmountCents,
                }) {
                  _controller.updateTier(
                    index,
                    place: place,
                    label: label,
                    percentageBps: percentageBps,
                    fixedAmountCents: fixedAmountCents,
                  );
                },
              ),
          ],
          if (draft.generalError != null) ...[
            const SizedBox(height: 8),
            Text(draft.generalError!),
          ],
          if (_controller.error != null) ...[
            const SizedBox(height: 8),
            Text(_controller.error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _controller.isSubmitting ? null : _controller.preview,
            child: const Text('Preview Awards'),
          ),
          const SizedBox(height: 12),
          if (_controller.previewRows.isNotEmpty) ...[
            const Text(
              'Preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final row in _controller.previewRows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.displayName),
                subtitle: Text(row.displayRank),
                trailing: Text('${row.awardAmountCents} cents'),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _controller.isSubmitting ? null : _controller.lockAwards,
              child: const Text('Lock Prize Awards'),
            ),
            if (_controller.lockedAwards.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _openLockedAwards,
                child: const Text('View Locked Awards'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TierEditor extends StatelessWidget {
  const _TierEditor({
    super.key,
    required this.tierIndex,
    required this.tier,
    required this.mode,
    required this.onChanged,
    this.error,
  });

  final int tierIndex;
  final PrizeTierDraftInput tier;
  final PrizePlanMode mode;
  final String? error;
  final void Function({
    int? place,
    String? label,
    int? percentageBps,
    int? fixedAmountCents,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              key: ValueKey('tier-$tierIndex-place'),
              initialValue: tier.place.toString(),
              decoration: const InputDecoration(labelText: 'Place'),
              keyboardType: TextInputType.number,
              onChanged: (value) =>
                  onChanged(place: int.tryParse(value) ?? tier.place),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('tier-$tierIndex-label'),
              initialValue: tier.label ?? '',
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (value) => onChanged(label: value),
            ),
            const SizedBox(height: 8),
            if (mode == PrizePlanMode.fixed)
              TextFormField(
                key: ValueKey('tier-$tierIndex-amount'),
                initialValue: tier.fixedAmountCents?.toString() ?? '',
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                onChanged: (value) => onChanged(
                  fixedAmountCents: int.tryParse(value),
                ),
              ),
            if (mode == PrizePlanMode.percentage)
              TextFormField(
                key: ValueKey('tier-$tierIndex-percentage'),
                initialValue: tier.percentageBps?.toString() ?? '',
                decoration: const InputDecoration(labelText: 'Percent (bps)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => onChanged(
                  percentageBps: int.tryParse(value),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!),
            ],
          ],
        ),
      ),
    );
  }
}
