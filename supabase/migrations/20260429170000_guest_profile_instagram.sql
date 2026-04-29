-- Add host-scoped Instagram handles to guest profiles.

alter table public.guest_profiles
add column if not exists instagram_handle text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'guest_profiles_instagram_handle_format_check'
      and conrelid = 'public.guest_profiles'::regclass
  ) then
    alter table public.guest_profiles
    add constraint guest_profiles_instagram_handle_format_check
    check (
      instagram_handle is null
      or instagram_handle ~ '^[a-z0-9._]{1,30}$'
    );
  end if;
end;
$$;

create unique index if not exists guest_profiles_owner_instagram_unique
  on public.guest_profiles (owner_user_id, instagram_handle)
  where instagram_handle is not null;
