-- Cap HK Standard scoring at 10 fan.

do $$
declare
  hk_standard_definition jsonb := '{
    "id": "HK_STANDARD",
    "name": "Hong Kong Standard",
    "minimumWinningFan": 3,
    "winTypes": ["discard", "self_draw"],
    "fanBuckets": [
      { "min": 3, "max": 3, "basePoints": 8 },
      { "min": 4, "max": 4, "basePoints": 16 },
      { "min": 5, "max": 5, "basePoints": 24 },
      { "min": 6, "max": 6, "basePoints": 32 },
      { "min": 7, "max": 7, "basePoints": 48 },
      { "min": 8, "max": 8, "basePoints": 64 },
      { "min": 9, "max": 9, "basePoints": 96 },
      { "min": 10, "basePoints": 128 }
    ],
    "washoutDealerBehavior": "retain_current_east",
    "rotationPolicyDefaults": ["dealer_cycle_return_to_initial_east"]
  }'::jsonb;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rulesets'
      and column_name = 'version'
  ) then
    insert into public.rulesets (
      id,
      name,
      version,
      status,
      definition_json
    ) values (
      'HK_STANDARD',
      'Hong Kong Standard',
      1,
      'active',
      hk_standard_definition
    )
    on conflict (id) do update
    set
      name = excluded.name,
      version = excluded.version,
      status = excluded.status,
      definition_json = excluded.definition_json;
  else
    insert into public.rulesets (
      id,
      name,
      status,
      definition_json
    ) values (
      'HK_STANDARD',
      'Hong Kong Standard',
      'active',
      hk_standard_definition
    )
    on conflict (id) do update
    set
      name = excluded.name,
      status = excluded.status,
      definition_json = excluded.definition_json;
  end if;
end;
$$;

create or replace function app_private.hk_base_points(
  target_fan_count integer
)
returns integer
language sql
immutable
as $$
  select case
    when target_fan_count < 0 then null
    when target_fan_count = 0 then 1
    when target_fan_count = 1 then 2
    when target_fan_count = 2 then 4
    when target_fan_count = 3 then 8
    when target_fan_count = 4 then 16
    when target_fan_count = 5 then 24
    when target_fan_count = 6 then 32
    when target_fan_count = 7 then 48
    when target_fan_count = 8 then 64
    when target_fan_count = 9 then 96
    else 128
  end
$$;

do $$
declare
  session_id uuid;
begin
  for session_id in
    select distinct hand_result.table_session_id
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where session.ruleset_id = 'HK_STANDARD'
      and hand_result.result_type = 'win'
      and hand_result.status = 'recorded'
      and hand_result.fan_count >= 10
  loop
    perform app_private.recalculate_session_unowned(session_id);
  end loop;
end;
$$;
