comment on column public.guest_profiles.public_display_name is
  'Canonical saved guest public alias for the host-owned guest profile. Event rows may copy or override this value for event-specific public display.';

comment on column public.event_guests.public_display_name is
  'Event-scoped public alias snapshot used for public event outputs. This may differ from public.guest_profiles.public_display_name for the same saved guest.';

comment on function public.default_public_display_name(text) is
  'Generates the default public alias from a full guest name when no explicit public display name is supplied.';

comment on function app_private.set_public_display_name() is
  'Trigger helper that fills blank public_display_name values from display_name on guest profile and event guest rows.';
