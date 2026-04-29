-- Lock down the shared ruleset catalog.
-- Rulesets are client-readable reference data, but only migrations should write them.

alter table public.rulesets enable row level security;

drop policy if exists rulesets_select_authenticated on public.rulesets;
create policy rulesets_select_authenticated
on public.rulesets
for select
to authenticated
using (true);

select pg_notify('pgrst', 'reload schema');
