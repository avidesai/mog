-- Mog backend — initial schema (eng doc, "Backend" + "Habit-layer data model").
--
-- Principles encoded here:
--   * The server never sees face data. There is no column that could hold an image, a landmark,
--     a mesh, an embedding or a depth map. `metrics_json` is a flat map of named scalars and a
--     CHECK constraint refuses anything else.
--   * Every table that holds user data has RLS on, and the only policy is "a user can read and
--     write their own rows". There is no service-role path in the app.
--   * Rows exist on the server only if the user opted into sync (a separate consent). The app
--     enforces that; the server records which consent was active when the row was written.
--   * Deletion is one function, hard-deletes, and is exercised by a test (tests/deletion_test.sql).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- users
-- auth.users is Supabase's table (Sign in with Apple). This is our profile row.
create table public.users (
  id               uuid primary key references auth.users (id) on delete cascade,
  created_at       timestamptz not null default now(),
  age_attested_at  timestamptz,                    -- time of the 18+ attestation; never a DOB
  sex_reference    text check (sex_reference in ('male','female')),
  age_band         text check (age_band in ('18-24','25-34','35-44','45+')),
  time_budget_min  int  check (time_budget_min in (5,15,30)),
  goals            text[] not null default '{}',
  state_attested   text,                            -- two-letter US state or null
  deleted_at       timestamptz                      -- tombstone; see delete_everything()
);

-- ------------------------------------------------------------- consents
create table public.consents (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users (id) on delete cascade,
  kind            text not null check (kind in ('measurement','sync','calibration')),
  policy_version  text not null,
  granted_at      timestamptz not null default now(),
  revoked_at      timestamptz,
  ip_country      text                              -- coarse, from the edge; never an IP address
);
create index on public.consents (user_id, kind, granted_at desc);

-- ---------------------------------------------------------- entitlements
-- Mirrored from RevenueCat webhooks by an Edge Function; the app reads RevenueCat directly and
-- this is a server-side copy for support and analytics.
create table public.entitlements (
  user_id     uuid not null references public.users (id) on delete cascade,
  product     text not null,
  status      text not null check (status in ('active','expired','refunded','trial')),
  expires_at  timestamptz,
  source      text not null default 'revenuecat',
  updated_at  timestamptz not null default now(),
  primary key (user_id, product)
);

-- A JSON object whose every value is a number. No arrays, no nested objects, no strings —
-- nothing that could smuggle coordinates or a template.
create or replace function public.is_flat_scalar_map(j jsonb) returns boolean
language sql immutable as $$
  select jsonb_typeof(j) = 'object'
     and not exists (select 1 from jsonb_each(j) where jsonb_typeof(value) <> 'number')
$$;

-- ----------------------------------------------------------------- scans
-- One row per capture that the user chose to sync. metrics_json: {"canthal_tilt_deg": 4.1, ...}
create table public.scans (
  id                    uuid primary key,                         -- generated on device
  user_id               uuid not null references public.users (id) on delete cascade,
  created_at            timestamptz not null,
  local_date            date not null,                            -- device-local calendar date
  model_version         text not null,
  metric_version        int  not null,
  score_point           numeric(4,2) not null check (score_point between 0 and 10),
  score_low             numeric(4,2) not null,
  score_high            numeric(4,2) not null,
  tier                  text not null check (tier in ('LTN','MTN','HTN','Chadlite','Chad')),
  profile_captured      boolean not null default false,
  capture_quality_json  jsonb not null default '{}'::jsonb,       -- gate stats, categorical only
  metrics_json          jsonb not null,
  suppressed_json       jsonb not null default '{}'::jsonb,       -- {"metric_id": "reason"}
  sync_consent_id       uuid not null references public.consents (id),
  constraint metrics_are_flat_scalars check (public.is_flat_scalar_map(metrics_json)),
  constraint metrics_are_small       check (pg_column_size(metrics_json) < 8192)
);
create index on public.scans (user_id, created_at desc);

-- ----------------------------------------------------------------- plans
create table public.plans (
  id            uuid primary key,
  scan_id       uuid not null references public.scans (id) on delete cascade,
  user_id       uuid not null references public.users (id) on delete cascade,
  rule_ids      text[] not null,
  professional_rule_ids text[] not null default '{}',
  goals         text[] not null,
  rules_version int  not null,
  generated_at  timestamptz not null default now()
);
create index on public.plans (user_id);

-- ----------------------------------------------------------- habit layer
create table public.plan_tasks (
  id            text not null,                                     -- "task_<rule_id>"
  plan_id       uuid not null references public.plans (id) on delete cascade,
  user_id       uuid not null references public.users (id) on delete cascade,
  rule_id       text not null,
  title         text not null,
  finding_refs  text[] not null default '{}',
  cadence       text not null check (cadence in ('daily','weekly','once')),
  weekly_target int,
  opens_week    int  not null check (opens_week between 1 and 8),
  time_cost_min int  not null default 0,
  sort_rank     int  not null,
  primary key (plan_id, id)
);

create table public.task_completions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete cascade,
  task_id       text not null,
  local_date    date not null,
  completed_at  timestamptz not null default now(),
  unique (user_id, task_id, local_date)
);

create table public.streaks (
  user_id             uuid primary key references public.users (id) on delete cascade,
  plan_start          date not null,
  current_days        int  not null default 0,
  longest_days        int  not null default 0,
  last_complete_date  date,
  repair_used_month   text,                                         -- 'YYYY-MM'
  distress_last_shown date,
  updated_at          timestamptz not null default now()
);

create table public.weeks (
  user_id        uuid not null references public.users (id) on delete cascade,
  week_index     int  not null check (week_index between 1 and 8),
  days_complete  int  not null default 0,
  banked_at      timestamptz,
  primary key (user_id, week_index)
);

create table public.scan_windows (
  user_id     uuid not null references public.users (id) on delete cascade,
  week_index  int  not null check (week_index in (4,8)),
  opens_on    date not null,
  scan_id     uuid references public.scans (id) on delete set null,
  primary key (user_id, week_index)
);

-- --------------------------------------------------------- reference data
-- Public, read-only. Lets a future model version ship a new reference table without an app update.
create table public.reference_dists (
  id             uuid primary key default gen_random_uuid(),
  model_version  text not null,
  sex            text not null check (sex in ('male','female')),
  ancestry_group text not null default 'pooled',
  age_band       text not null default 'all',
  quantiles_json jsonb not null,
  published_at   timestamptz not null default now(),
  unique (model_version, sex, ancestry_group, age_band)
);

create table public.model_versions (
  version       text primary key,
  rules_version int  not null,
  released_at   timestamptz not null default now(),
  changelog     text not null                                       -- shown in the "model changed" card
);

-- ------------------------------------------------------------------ RLS
alter table public.users            enable row level security;
alter table public.consents         enable row level security;
alter table public.entitlements     enable row level security;
alter table public.scans            enable row level security;
alter table public.plans            enable row level security;
alter table public.plan_tasks       enable row level security;
alter table public.task_completions enable row level security;
alter table public.streaks          enable row level security;
alter table public.weeks            enable row level security;
alter table public.scan_windows     enable row level security;
alter table public.reference_dists  enable row level security;
alter table public.model_versions   enable row level security;

create policy "own row"  on public.users            for all using (id = auth.uid()) with check (id = auth.uid());
create policy "own rows" on public.consents         for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.entitlements     for select using (user_id = auth.uid());
create policy "own rows" on public.scans            for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.plans            for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.plan_tasks       for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.task_completions for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.streaks          for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.weeks            for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.scan_windows     for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "public read" on public.reference_dists for select using (true);
create policy "public read" on public.model_versions  for select using (true);

-- A scan may only be written while a sync consent is active for this user.
create or replace function public.require_active_sync_consent() returns trigger
language plpgsql as $$
begin
  if not exists (
    select 1 from public.consents c
    where c.id = new.sync_consent_id and c.user_id = new.user_id and c.kind = 'sync' and c.revoked_at is null
  ) then
    raise exception 'sync consent % is not active for user %', new.sync_consent_id, new.user_id;
  end if;
  return new;
end $$;
create trigger scans_require_sync_consent before insert or update on public.scans
  for each row execute function public.require_active_sync_consent();

-- Processed by a scheduled Edge Function: removes auth.users rows (which cascades the tombstoned
-- profile) and consent rows older than 3 years. Keeping this queue is what lets us prove the
-- 30-day promise in the policy.
create table public.deletion_queue (
  user_id      uuid primary key,
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);
alter table public.deletion_queue enable row level security;   -- no policies: service role only

-- ------------------------------------------------------- delete everything
-- Called by the app (as the user). Hard-deletes every row the user owns, tombstones the profile,
-- and schedules the auth user for removal. Consent rows are retained (3 years, legal evidence) but
-- stripped of everything except kind/version/timestamps — they already hold nothing else.
create or replace function public.delete_everything() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not authenticated'; end if;
  delete from public.scan_windows     where user_id = uid;
  delete from public.weeks            where user_id = uid;
  delete from public.streaks          where user_id = uid;
  delete from public.task_completions where user_id = uid;
  delete from public.plan_tasks       where user_id = uid;
  delete from public.plans            where user_id = uid;
  delete from public.scans            where user_id = uid;
  delete from public.entitlements     where user_id = uid;
  update public.consents set revoked_at = coalesce(revoked_at, now()) where user_id = uid;
  update public.users set deleted_at = now(), goals = '{}', state_attested = null,
                          sex_reference = null, age_band = null, time_budget_min = null where id = uid;
  insert into public.deletion_queue (user_id) values (uid) on conflict do nothing;
end $$;
revoke all on function public.delete_everything() from public;
grant execute on function public.delete_everything() to authenticated;

