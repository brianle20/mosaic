-- Merge safe duplicate saved guest profiles created by repeated name-only adds.

create temp table duplicate_guest_profiles_to_merge
on commit drop
as
with profile_groups as (
  select
    concat_ws(
      '|',
      profile.owner_user_id::text,
      profile.normalized_name,
      coalesce(profile.public_display_name, '')
    ) as profile_group_key,
    profile.owner_user_id,
    profile.normalized_name,
    coalesce(profile.public_display_name, '') as public_display_name_key,
    (array_agg(profile.id order by profile.created_at, profile.id))[1]
      as canonical_profile_id,
    count(*) as profile_count
  from public.guest_profiles as profile
  group by
    profile.owner_user_id,
    profile.normalized_name,
    coalesce(profile.public_display_name, '')
  having count(*) > 1
    and count(distinct profile.phone_e164) <= 1
    and count(distinct profile.email_lower) <= 1
    and count(distinct profile.instagram_handle) <= 1
),
event_guest_conflicts as (
  select
    profile_group.profile_group_key,
    guest.event_id
  from profile_groups as profile_group
  join public.guest_profiles as profile
    on profile.owner_user_id = profile_group.owner_user_id
    and profile.normalized_name = profile_group.normalized_name
    and coalesce(profile.public_display_name, '') =
      profile_group.public_display_name_key
  join public.event_guests as guest
    on guest.guest_profile_id = profile.id
  group by profile_group.profile_group_key, guest.event_id
  having count(*) > 1
)
select
  duplicate.profile_group_key,
  duplicate.canonical_profile_id,
  profile.id as duplicate_profile_id
from profile_groups as duplicate
join public.guest_profiles as profile
  on profile.owner_user_id = duplicate.owner_user_id
  and profile.normalized_name = duplicate.normalized_name
  and coalesce(profile.public_display_name, '') =
    duplicate.public_display_name_key
where profile.id <> duplicate.canonical_profile_id
  and not exists (
    select 1
    from event_guest_conflicts as conflict
    where conflict.profile_group_key = duplicate.profile_group_key
  );

update public.event_guests as guest
set guest_profile_id = duplicate.canonical_profile_id
from duplicate_guest_profiles_to_merge as duplicate
where guest.guest_profile_id = duplicate.duplicate_profile_id;

delete from public.guest_profiles as profile
using duplicate_guest_profiles_to_merge as duplicate
where profile.id = duplicate.duplicate_profile_id;

drop table duplicate_guest_profiles_to_merge;
