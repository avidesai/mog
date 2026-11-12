-- Deletion path test (eng doc: "Deletion is tested in CI against the actual schema").
-- Runs after the migrations. Fails loudly (RAISE) if any user-owned row survives delete_everything().
-- Also checks the two guards: non-scalar metrics_json is refused, and a scan cannot be written
-- without an active sync consent.

begin;

-- two users
insert into auth.users (id) values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
insert into public.users (id, age_attested_at, sex_reference, age_band, time_budget_min, goals)
values ('00000000-0000-0000-0000-000000000001', now(), 'male', '18-24', 15, '{sharper_jawline}'),
       ('00000000-0000-0000-0000-000000000002', now(), 'female', '25-34', 5, '{better_skin}');

-- act as user 1
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
set local role authenticated;

insert into public.consents (id, user_id, kind, policy_version) values
  ('10000000-0000-0000-0000-000000000001', auth.uid(), 'measurement', '1.0'),
  ('10000000-0000-0000-0000-000000000002', auth.uid(), 'sync', '1.0');

insert into public.scans (id, user_id, created_at, local_date, model_version, metric_version, score_point, score_low, score_high, tier, metrics_json, sync_consent_id)
values ('20000000-0000-0000-0000-000000000001', auth.uid(), now(), current_date, 'rules-1.0.0', 1, 6.4, 5.9, 6.9, 'HTN',
        '{"canthal_tilt_deg": 4.1, "symmetry_index": 0.95}', '10000000-0000-0000-0000-000000000002');

insert into public.plans (id, scan_id, user_id, rule_ids, goals, rules_version)
values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', auth.uid(), '{spf_daily,sleep_regular}', '{sharper_jawline}', 1);
insert into public.plan_tasks (id, plan_id, user_id, rule_id, title, cadence, opens_week, sort_rank)
values ('task_spf_daily', '30000000-0000-0000-0000-000000000001', auth.uid(), 'spf_daily', 'SPF', 'daily', 1, 0);
insert into public.task_completions (user_id, task_id, local_date) values (auth.uid(), 'task_spf_daily', current_date);
insert into public.streaks (user_id, plan_start, current_days) values (auth.uid(), current_date, 1);
insert into public.weeks (user_id, week_index, days_complete) values (auth.uid(), 1, 1);
insert into public.scan_windows (user_id, week_index, opens_on, scan_id) values (auth.uid(), 4, current_date + 21, '20000000-0000-0000-0000-000000000001');

-- guard 1: non-scalar metrics are refused
do $$ begin
  begin
    insert into public.scans (id, user_id, created_at, local_date, model_version, metric_version, score_point, score_low, score_high, tier, metrics_json, sync_consent_id)
    values (gen_random_uuid(), auth.uid(), now(), current_date, 'rules-1.0.0', 1, 6, 5, 7, 'MTN',
            '{"landmarks": [[0.1, 0.2, 0.3]]}', '10000000-0000-0000-0000-000000000002');
    raise exception 'GUARD FAILED: array value accepted in metrics_json';
  exception when check_violation then null;
  end;
end $$;

-- guard 2: no scan without an active sync consent
update public.consents set revoked_at = now() where id = '10000000-0000-0000-0000-000000000002';
do $$ begin
  begin
    insert into public.scans (id, user_id, created_at, local_date, model_version, metric_version, score_point, score_low, score_high, tier, metrics_json, sync_consent_id)
    values (gen_random_uuid(), auth.uid(), now(), current_date, 'rules-1.0.0', 1, 6, 5, 7, 'MTN', '{"a": 1}', '10000000-0000-0000-0000-000000000002');
    raise exception 'GUARD FAILED: scan written against a revoked sync consent';
  exception when raise_exception then
    if sqlerrm like 'GUARD FAILED%' then raise; end if;
  end;
end $$;

-- guard 3: RLS — user 1 cannot see user 2's profile
do $$ begin
  if exists (select 1 from public.users where id = '00000000-0000-0000-0000-000000000002') then
    raise exception 'GUARD FAILED: RLS leaked another user''s row';
  end if;
end $$;

-- the deletion
select public.delete_everything();

do $$
declare n int;
begin
  select count(*) into n from (
    select user_id from public.scans where user_id = auth.uid()
    union all select user_id from public.plans where user_id = auth.uid()
    union all select user_id from public.plan_tasks where user_id = auth.uid()
    union all select user_id from public.task_completions where user_id = auth.uid()
    union all select user_id from public.streaks where user_id = auth.uid()
    union all select user_id from public.weeks where user_id = auth.uid()
    union all select user_id from public.scan_windows where user_id = auth.uid()
    union all select user_id from public.entitlements where user_id = auth.uid()
  ) t;
  if n <> 0 then raise exception 'DELETION FAILED: % user-owned rows remain', n; end if;
  if not exists (select 1 from public.users where id = auth.uid() and deleted_at is not null and goals = '{}' and state_attested is null) then
    raise exception 'DELETION FAILED: profile not tombstoned';
  end if;
  if exists (select 1 from public.consents where user_id = auth.uid() and revoked_at is null) then
    raise exception 'DELETION FAILED: an active consent survived';
  end if;
end $$;

-- the queue got the request (service-role view)
reset role;
-- simulate process-deletions: removing the auth user cascades everything EXCEPT consents
delete from auth.users where id = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if exists (select 1 from public.users where id = '00000000-0000-0000-0000-000000000001') then
    raise exception 'DELETION FAILED: profile survived auth user removal';
  end if;
  if (select count(*) from public.consents where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002')) <> 2 then
    raise exception 'RETENTION FAILED: consent records did not survive account deletion';
  end if;
  if exists (select 1 from public.consents where id = '10000000-0000-0000-0000-000000000001' and user_id is not null) then
    raise exception 'RETENTION FAILED: consent still points at a deleted user';
  end if;
end $$;
do $$ begin
  if not exists (select 1 from public.deletion_queue where user_id = '00000000-0000-0000-0000-000000000001') then
    raise exception 'DELETION FAILED: not queued for auth removal';
  end if;
end $$;

select 'deletion_test: all guards and deletion OK' as result;
rollback;
