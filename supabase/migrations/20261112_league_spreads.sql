-- ESPN spread snapshots, frozen at kickoff by server-side policy.
-- This is informational only; league_picks and scoring are unchanged.
create table if not exists public.league_spreads (
 game_id text primary key references public.league_games(id),
 favored_team text,
 spread_points numeric(5,1),
 source text not null default 'ESPN',
 observed_at timestamptz not null default now(),
 frozen_at timestamptz,
 check (spread_points is null or spread_points >= 0),
 check (source = 'ESPN')
);
alter table public.league_spreads enable row level security;
drop policy if exists "members read league spreads" on public.league_spreads;
create policy "members read league spreads" on public.league_spreads for select to authenticated
using (exists(select 1 from public.league_members m where m.user_id=auth.uid()));
-- Only service-role jobs may write; browser sessions have no write policy.
revoke insert,update,delete on public.league_spreads from anon,authenticated;
grant select on public.league_spreads to authenticated;
