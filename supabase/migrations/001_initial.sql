-- ============================================================
-- Drinking Tracker — Initial Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- user_profiles
-- ------------------------------------------------------------
create table if not exists user_profiles (
    user_id        text primary key,   -- Firebase UID
    display_name   text not null default '',
    weight_kg      double precision not null default 70,
    height_cm      double precision not null default 170,
    biological_sex text not null default 'other'
        check (biological_sex in ('male', 'female', 'other')),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

-- ------------------------------------------------------------
-- drink_logs
-- ------------------------------------------------------------
create table if not exists drink_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       text not null references user_profiles(user_id) on delete cascade,
    timestamp     timestamptz not null default now(),
    alcohol_type  text not null
        check (alcohol_type in ('beer', 'wine', 'spirits', 'cocktail', 'cider', 'other')),
    percentage    double precision not null check (percentage > 0 and percentage <= 100),
    volume_ml     double precision not null check (volume_ml > 0)
);

create index if not exists drink_logs_user_ts on drink_logs (user_id, timestamp desc);

-- ------------------------------------------------------------
-- analysis_logs
-- ------------------------------------------------------------
create table if not exists analysis_logs (
    id              uuid primary key default gen_random_uuid(),
    user_id         text not null references user_profiles(user_id) on delete cascade,
    timestamp       timestamptz not null default now(),
    bac_estimated   double precision not null default 0,
    stage           integer not null default 0 check (stage between 0 and 5),
    heart_rate      double precision,
    hrv             double precision,
    spo2            double precision,
    slur_score      double precision check (slur_score between 0 and 1),
    blush_score     double precision check (blush_score between 0 and 1),
    gemini_summary  text,
    trigger         text not null default 'manual'
        check (trigger in ('manual', 'auto'))
);

create index if not exists analysis_logs_user_ts on analysis_logs (user_id, timestamp desc);

-- ------------------------------------------------------------
-- Row Level Security
-- All tables: users can only see/modify their own rows.
-- We use Firebase UID stored in user_id column.
-- Since we're using Supabase with a service key on client
-- (hackathon mode), RLS is set to permissive but still correct.
-- For production: set up Supabase custom JWT with Firebase JWKS.
-- ------------------------------------------------------------
alter table user_profiles  enable row level security;
alter table drink_logs     enable row level security;
alter table analysis_logs  enable row level security;

-- Policies (using service role key bypasses these; for JWT auth they apply)
create policy "Users read own profile"
    on user_profiles for select
    using (true);  -- relax for hackathon; tighten with: auth.uid() = user_id

create policy "Users write own profile"
    on user_profiles for all
    using (true);

create policy "Users read own drink logs"
    on drink_logs for select
    using (true);

create policy "Users write own drink logs"
    on drink_logs for all
    using (true);

create policy "Users read own analysis logs"
    on analysis_logs for select
    using (true);

create policy "Users write own analysis logs"
    on analysis_logs for all
    using (true);
