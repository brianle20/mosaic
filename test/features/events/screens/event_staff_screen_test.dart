import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/event_staff_screen.dart';

class _FakeStaffRepository implements StaffRepository {
  const _FakeStaffRepository();

  @override
  Future<List<EventStaffMembershipRecord>> listEventStaff(
      String eventId) async {
    return const [];
  }

  @override
  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  ) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('uses a single left-side back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const EventStaffScreen(
                          eventId: 'event-1',
                          eventTitle: 'FV Mahjong 2',
                          staffRepository: _FakeStaffRepository(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open staff'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open staff'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byKey(const ValueKey('softHostBackButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('eventStaffBackAction')), findsNothing);
  });
}
