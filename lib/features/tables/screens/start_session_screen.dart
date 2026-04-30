import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/start_session_controller.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({
    super.key,
    required this.eventId,
    required this.table,
    required this.guestRepository,
    required this.sessionRepository,
    required this.nfcService,
    this.preverifiedTableTagUid,
  });

  final String eventId;
  final EventTableRecord table;
  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;
  final NfcService nfcService;
  final String? preverifiedTableTagUid;

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  late final StartSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StartSessionController(
      table: widget.table,
      guestRepository: widget.guestRepository,
      sessionRepository: widget.sessionRepository,
      preverifiedTableTagUid: widget.preverifiedTableTagUid,
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

  Future<void> _scanNext() async {
    switch (_controller.state.currentStep) {
      case StartSessionScanStep.scanTable:
        final result = await widget.nfcService.scanTableTag(context);
        if (result != null) {
          _controller.recordTableScan(result.normalizedUid);
        }
      case StartSessionScanStep.scanEast:
      case StartSessionScanStep.scanSouth:
      case StartSessionScanStep.scanWest:
      case StartSessionScanStep.scanNorth:
        final seatLabel = _controller.state.currentSeatLabel!;
        final result = await widget.nfcService.scanPlayerTagForSessionSeat(
          context,
          seatLabel: seatLabel,
        );
        if (result != null) {
          _controller.recordPlayerScan(result.normalizedUid);
        }
      case StartSessionScanStep.review:
        return;
    }
  }

  Future<void> _confirm() async {
    final started = await _controller.confirmStart();
    if (!mounted || started == null) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRouter.sessionDetailRoute,
      arguments: SessionDetailArgs(
        eventId: widget.eventId,
        sessionId: started.session.id,
        scoringOpen: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Session')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.table.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(_controller.currentPrompt),
            const SizedBox(height: 12),
            for (final seat in _controller.resolvedSeats)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_capitalize(seat.seatLabel)),
                subtitle: Text(seat.guestName),
              ),
            if (_controller.actionError != null) ...[
              const SizedBox(height: 12),
              Text(_controller.actionError!),
            ],
            const SizedBox(height: 20),
            if (_controller.state.currentStep != StartSessionScanStep.review)
              FilledButton(
                onPressed: _scanNext,
                child: const Text('Scan Next Tag'),
              ),
            if (_controller.state.currentStep == StartSessionScanStep.review)
              FilledButton(
                onPressed: _controller.isSubmitting ? null : _confirm,
                child: Text(
                  _controller.isSubmitting
                      ? 'Starting...'
                      : 'Confirm Start Session',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }

  return '${value[0].toUpperCase()}${value.substring(1)}';
}
