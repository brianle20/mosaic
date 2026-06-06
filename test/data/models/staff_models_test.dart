import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/staff_models.dart';

void main() {
  test('EventStaffMembershipRecord normalizes legacy qualification role rows',
      () {
    final record = EventStaffMembershipRecord.fromJson(const {
      'id': 'mem_01',
      'event_id': 'evt_01',
      'approved_identity_id': 'identity_01',
      'user_id': null,
      'display_name': 'Michelle',
      'phone_e164': '+15551234567',
      'role': 'qualification_scorer',
      'status': 'active',
      'created_at': '2026-05-28T10:00:00Z',
      'updated_at': '2026-05-28T10:30:00Z',
    });

    expect(record.displayName, 'Michelle');
    expect(record.role, EventStaffRole.eventScorer);
    expect(record.status, EventStaffStatus.active);
    expect(record.createdAt, DateTime.parse('2026-05-28T10:00:00Z'));
  });
}
