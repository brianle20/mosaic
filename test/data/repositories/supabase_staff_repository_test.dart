import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/supabase_staff_repository.dart';

void main() {
  test('lists, upserts, and disables event staff through RPCs', () async {
    final calls = <String, Map<String, dynamic>>{};
    final repository = SupabaseStaffRepository.withRpcRunner(
      rpcRunner: (name, params) async {
        calls[name] = params;
        if (name == 'list_event_staff_memberships') {
          return [
            {
              'id': 'mem_01',
              'event_id': 'evt_01',
              'approved_identity_id': 'identity_01',
              'user_id': null,
              'email': 'michelle@example.com',
              'display_name': 'Michelle',
              'phone_e164': null,
              'role': 'event_scorer',
              'status': 'active',
              'created_at': '2026-05-28T10:00:00Z',
              'updated_at': '2026-05-28T10:30:00Z',
            },
          ];
        }
        return [
          {
            'id': params['target_membership_id'] ?? 'mem_01',
            'event_id': params['target_event_id'] ?? 'evt_01',
            'approved_identity_id': 'identity_01',
            'user_id': null,
            'email': params['staff_email'] ?? 'michelle@example.com',
            'display_name': params['staff_display_name'] ?? 'Michelle',
            'phone_e164': params['staff_phone_e164'],
            'role': params['staff_role'] ?? 'event_scorer',
            'status': name == 'disable_event_staff_membership'
                ? 'disabled'
                : 'active',
            'created_at': '2026-05-28T10:00:00Z',
            'updated_at': '2026-05-28T10:30:00Z',
          },
        ];
      },
    );

    final staff = await repository.listEventStaff('evt_01');
    expect(staff, hasLength(1));
    expect(staff.single.email, 'michelle@example.com');
    expect(staff.single.phoneE164, isNull);
    expect(calls['list_event_staff_memberships'], {
      'target_event_id': 'evt_01',
    });

    final upserted = await repository.upsertEventStaff(
      const UpsertEventStaffMembershipInput(
        eventId: 'evt_01',
        email: 'michelle@example.com',
        displayName: 'Michelle',
        role: EventStaffRole.eventScorer,
      ),
    );
    expect(upserted.role, EventStaffRole.eventScorer);
    expect(calls['upsert_event_staff_membership'], {
      'target_event_id': 'evt_01',
      'staff_email': 'michelle@example.com',
      'staff_phone_e164': null,
      'staff_display_name': 'Michelle',
      'staff_role': 'event_scorer',
    });

    final disabled = await repository.disableEventStaffMembership('mem_01');
    expect(disabled.status, EventStaffStatus.disabled);
    expect(calls['disable_event_staff_membership'], {
      'target_membership_id': 'mem_01',
    });
  });
}
