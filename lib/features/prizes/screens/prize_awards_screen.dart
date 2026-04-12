import 'package:flutter/material.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/prizes/controllers/prize_awards_controller.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_controller.error != null) Text(_controller.error!),
          for (final award in _controller.awards)
            Card(
              child: ListTile(
                title: Text(
                  widget.guestNamesById[award.eventGuestId] ??
                      award.eventGuestId,
                ),
                subtitle: Text(award.displayRank),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${award.awardAmountCents} cents'),
                    Text(_statusLabel(award.status)),
                  ],
                ),
              ),
            ),
          for (final award in _controller.awards)
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
    );
  }

  String _statusLabel(PrizeAwardStatus status) {
    return switch (status) {
      PrizeAwardStatus.planned => 'planned',
      PrizeAwardStatus.paid => 'paid',
      PrizeAwardStatus.voided => 'void',
    };
  }
}
