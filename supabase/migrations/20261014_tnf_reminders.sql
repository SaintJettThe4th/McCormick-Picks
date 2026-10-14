-- Foundation only. Run after enabling Supabase Auth and migrating authoritative picks.
create table if not exists public.tnf_games (
  id text primary key,
  away_team text not null,
  home_team text not null,
  kickoff_at timestamptz not null,
  season integer not null,
  week integer not null,
  unique(season,week)
);
create table if not exists public.tnf_picks (
  game_id text not null references public.tnf_games(id),
  user_id uuid not null references auth.users(id),
  team text not null,
  submitted_at timestamptz not null default now(),
  primary key (game_id,user_id)
);
create table if not exists public.push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);
create table if not exists public.tnf_reminder_deliveries (
  game_id text not null references public.tnf_games(id),
  user_id uuid not null references auth.users(id),
  slot text not null check (slot in ('noon','one_hour')),
  created_at timestamptz not null default now(),
  primary key (game_id,user_id,slot)
);
alter table public.tnf_games enable row level security;
alter table public.tnf_picks enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.tnf_reminder_deliveries enable row level security;
create policy "read tnf games" on public.tnf_games for select to authenticated using (true);
create policy "read own tnf picks" on public.tnf_picks for select to authenticated using (user_id = auth.uid());
create policy "read own push subscriptions" on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
create policy "insert own push subscriptions" on public.push_subscriptions for insert to authenticated with check (user_id = auth.uid());
create policy "delete own push subscriptions" on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());
-- No client write policy for picks or delivery records. Pick writes must use
-- an authenticated server endpoint that enforces kickoff and immutability.
