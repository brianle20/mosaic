import 'package:flutter/material.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class HandEvidenceReviewScreen extends StatefulWidget {
  const HandEvidenceReviewScreen({
    super.key,
    required this.eventId,
    required this.mosaicProfileRepository,
  });

  final String eventId;
  final MosaicProfileRepository mosaicProfileRepository;

  @override
  State<HandEvidenceReviewScreen> createState() =>
      _HandEvidenceReviewScreenState();
}

class _HandEvidenceReviewScreenState extends State<HandEvidenceReviewScreen> {
  late Future<List<HandPhotoRecord>> _reviewFuture;

  @override
  void initState() {
    super.initState();
    _reviewFuture = widget.mosaicProfileRepository.listHandEvidenceReview(
      widget.eventId,
    );
  }

  void _reload() {
    setState(() {
      _reviewFuture = widget.mosaicProfileRepository.listHandEvidenceReview(
        widget.eventId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hand Evidence Review')),
      body: FutureBuilder<List<HandPhotoRecord>>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.error_outline,
                  title: 'Unable to load hand evidence.',
                  message: 'Check your connection and try again.',
                  action: FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            );
          }

          final records = snapshot.data ?? const <HandPhotoRecord>[];
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.photo_library_outlined,
                  title: 'No hand evidence to review.',
                  message: 'Captured hand photos will appear here.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return _HandEvidenceReviewRow(record: records[index]);
            },
          );
        },
      ),
    );
  }
}

class _HandEvidenceReviewRow extends StatelessWidget {
  const _HandEvidenceReviewRow({required this.record});

  final HandPhotoRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.84),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(
            record.handResultId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            record.clientPhotoId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _uploadStatusLabel(record.uploadStatus),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

String _uploadStatusLabel(HandPhotoUploadStatus status) {
  return switch (status) {
    HandPhotoUploadStatus.pending => 'Pending',
    HandPhotoUploadStatus.uploaded => 'Uploaded',
    HandPhotoUploadStatus.failed => 'Failed',
  };
}
