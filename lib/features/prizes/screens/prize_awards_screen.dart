import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_awards_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class PrizeAwardsScreen extends StatefulWidget {
  const PrizeAwardsScreen({
    super.key,
    required this.eventId,
    required this.guestNamesById,
    required this.prizeRepository,
  });

  final String eventId;
  final Map<String, String> guestNamesById;
  final PrizeRepository prizeRepository;

  @override
  State<PrizeAwardsScreen> createState() => _PrizeAwardsScreenState();
}

class _PrizeAwardsScreenState extends State<PrizeAwardsScreen> {
  late final PrizeAwardsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrizeAwardsController(
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
      appBar: AppBar(title: const Text('Prize Awards')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: _controller.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Official Payout Checklist',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this locked list to track which awards are still payable, paid out, or void.',
            ),
            const SizedBox(height: 16),
            if (_controller.awards.isEmpty) ...[
              const EmptyStateCard(
                icon: Icons.checklist_rtl,
                title: 'No locked awards yet',
                message:
                    'Preview and lock prize awards before using the payout checklist.',
              ),
              const SizedBox(height: 16),
            ],
            for (final award in _controller.awards)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          award.displayName ??
                              widget.guestNamesById[award.eventGuestId] ??
                              award.eventGuestId,
                        ),
                        subtitle: Text(award.displayRank),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${award.awardAmountCents} cents'),
                            StatusChip(
                              label: _statusLabel(award.status),
                              tone: _statusTone(award.status),
                            ),
                          ],
                        ),
                      ),
                      if (award.status == PrizeAwardStatus.planned)
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _controller.markPaid(award.id),
                              child: const Text('Mark Paid'),
                            ),
                            TextButton(
                              onPressed: () => _controller.voidAward(award.id),
                              child: const Text('Void'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(PrizeAwardStatus status) {
    return switch (status) {
      PrizeAwardStatus.planned => 'Ready to Pay',
      PrizeAwardStatus.paid => 'Paid Out',
      PrizeAwardStatus.voided => 'Void Award',
    };
  }

  StatusChipTone _statusTone(PrizeAwardStatus status) {
    return switch (status) {
      PrizeAwardStatus.planned => StatusChipTone.warning,
      PrizeAwardStatus.paid => StatusChipTone.success,
      PrizeAwardStatus.voided => StatusChipTone.neutral,
    };
  }
}
