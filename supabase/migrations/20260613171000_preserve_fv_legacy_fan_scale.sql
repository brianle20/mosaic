-- Keep FV Mahjong 1 and FV Mahjong 2 on their historical uncapped fan scale.

do $$
declare
  legacy_definition jsonb := '{
    "id": "HK_STANDARD_LEGACY_UNCAPPED",
    "name": "Hong Kong Standard Legacy Uncapped",
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
      { "min": 10, "max": 10, "basePoints": 128 },
      { "min": 11, "max": 11, "basePoints": 192 },
      { "min": 12, "max": 12, "basePoints": 256 },
      { "min": 13, "basePoints": 384 }
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
      'HK_STANDARD_LEGACY_UNCAPPED',
      'Hong Kong Standard Legacy Uncapped',
      1,
      'active',
      legacy_definition
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
      'HK_STANDARD_LEGACY_UNCAPPED',
      'Hong Kong Standard Legacy Uncapped',
      'active',
      legacy_definition
    )
    on conflict (id) do update
    set
      name = excluded.name,
      status = excluded.status,
      definition_json = excluded.definition_json;
  end if;
end;
$$;

update public.table_sessions as session
set ruleset_id = 'HK_STANDARD_LEGACY_UNCAPPED'
from public.events as event
where event.id = session.event_id
  and (
    lower(btrim(coalesce(event.public_slug, ''))) in (
      'fv-mahjong-1',
      'fv-mahjong-2'
    )
    or lower(btrim(event.title)) in (
      'fv mahjong 1',
      'fv mahjong 2'
    )
  );

do $$
declare
  session_id uuid;
begin
  for session_id in
    select distinct session.id
    from public.table_sessions as session
    join public.events as event
      on event.id = session.event_id
    where session.ruleset_id = 'HK_STANDARD_LEGACY_UNCAPPED'
      and (
        lower(btrim(coalesce(event.public_slug, ''))) in (
          'fv-mahjong-1',
          'fv-mahjong-2'
        )
        or lower(btrim(event.title)) in (
          'fv mahjong 1',
          'fv mahjong 2'
        )
      )
      and exists (
        select 1
        from public.hand_results as hand_result
        where hand_result.table_session_id = session.id
          and hand_result.status = 'recorded'
      )
  loop
    perform app_private.recalculate_session_unowned(session_id);
  end loop;
end;
$$;
