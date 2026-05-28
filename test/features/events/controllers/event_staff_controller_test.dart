import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_staff_controller.dart';

class _FakeStaffRepository implements StaffRepository {
  final records = <EventStaffMembershipRecord>[];

  @override
  Future<List<EventStaffMembershipRecord>> listEventStaff(
      String eventId) async {
    return records;
  }

  @override
  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  ) async {
    final now = DateTime.utc(2026, 5, 28);
    final record = EventStaffMembershipRecord(
      id: 'staff_${input.phoneE164}',
      eventId: input.eventId,
      displayName: input.displayName,
      phoneE164: input.phoneE164,
      role: input.role,
      status: EventStaffStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    records
      ..removeWhere((existing) => existing.id == record.id)
      ..add(record);
    return record;
  }

  @override
  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  ) async {
    final index = records.indexWhere((record) => record.id == membershipId);
    final existing = records[index];
    final disabled = EventStaffMembershipRecord(
      id: existing.id,
      eventId: existing.eventId,
      displayName: existing.displayName,
      phoneE164: existing.phoneE164,
      role: existing.role,
      status: EventStaffStatus.disabled,
      createdAt: existing.createdAt,
      updatedAt: DateTime.utc(2026, 5, 28, 1),
    );
    records[index] = disabled;
    return disabled;
  }
}

void main() {
  test('loads, upserts, and disables staff memberships', () async {
    final repository = _FakeStaffRepository();
    final controller = EventStaffController(
      staffRepository: repository,
      eventId: 'evt_01',
    );

    await controller.load();
    expect(controller.memberships, isEmpty);

    final saved = await controller.upsertStaff(
      phoneE164: ' +15551234567 ',
      displayName: ' Score Helper ',
      role: EventStaffRole.eventScorer,
    );

    expect(saved, isTrue);
    expect(controller.memberships.single.displayName, 'Score Helper');
    expect(controller.memberships.single.phoneE164, '+15551234567');
    expect(controller.memberships.single.role, EventStaffRole.eventScorer);

    await controller.disableMembership(controller.memberships.single.id);

    expect(controller.memberships.single.status, EventStaffStatus.disabled);
  });
}
