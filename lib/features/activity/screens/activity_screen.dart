import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/activity/controllers/activity_controller.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.eventId,
    required this.activityRepository,
  });

  final String eventId;
  final ActivityRepository activityRepository;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivityController(
      activityRepository: widget.activityRepository,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: EventActivityCategory.values
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_labelForCategory(category)),
                          selected: _controller.selectedCategory == category,
                          onSelected: (_) => _controller.selectCategory(
                              widget.eventId, category),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            Expanded(
              child: _controller.entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No activity yet for this event.'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _controller.entries.length,
                      itemBuilder: (context, index) {
                        final entry = _controller.entries[index];
                        return Card(
                          child: ListTile(
                            title: Text(entry.summaryText),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_timestampFormat(entry.createdAt)),
                                if (entry.reason case final reason?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(reason),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _timestampFormat(DateTime value) {
    final local = value.toLocal();
    final month = switch (local.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => '',
    };
    final hour24 = local.hour;
    final meridiem = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = switch (hour24 % 12) {
      0 => 12,
      final value => value,
    };
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, $hour12:$minute $meridiem';
  }

  String _labelForCategory(EventActivityCategory category) {
    return switch (category) {
      EventActivityCategory.all => 'All',
      EventActivityCategory.guests => 'Guests',
      EventActivityCategory.payments => 'Payments',
      EventActivityCategory.sessions => 'Sessions',
      EventActivityCategory.prizes => 'Prizes',
      EventActivityCategory.event => 'Event',
      EventActivityCategory.other => 'Other',
    };
  }
}
