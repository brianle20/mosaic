comment on column public.guest_profiles.phone_e164 is
  'Canonical host-scoped saved guest phone number. New guest/contact writes should target guest_profiles, not event_guests.';

comment on column public.guest_profiles.email_lower is
  'Canonical host-scoped saved guest email. New guest/contact writes should target guest_profiles, not event_guests.';

comment on column public.event_guests.phone_e164 is
  'Legacy event guest contact snapshot retained for historical fallback reads. Canonical phone contact lives on public.guest_profiles.phone_e164; do not write new app contact updates here.';

comment on column public.event_guests.email_lower is
  'Legacy event guest contact snapshot retained for historical fallback reads. Canonical email contact lives on public.guest_profiles.email_lower; do not write new app contact updates here.';
