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

-- Atomic, database-clock-checked writes prevent updates after kickoff.
create or replace function public.record_espn_spread(
 p_game_id text,p_favored_team text,p_points numeric
) returns void language plpgsql security definer set search_path='' as $$
declare g public.league_games%rowtype;
begin
 if current_user <> 'service_role' then raise exception 'Service role only'; end if;
 select * into g from public.league_games where id=p_game_id for update;
 if not found or g.kickoff_at is null then return; end if;
 if clock_timestamp() >= g.kickoff_at then
   update public.league_spreads set frozen_at=coalesce(frozen_at,g.kickoff_at)
   where game_id=p_game_id and frozen_at is null;
   return;
 end if;
 if p_points is null or p_points<0 or
   (p_points=0 and p_favored_team is not null) or
   (p_points>0 and p_favored_team not in (g.home_team,g.away_team)) then
   raise exception 'Invalid spread';
 end if;
 insert into public.league_spreads(game_id,favored_team,spread_points,source,observed_at)
 values(p_game_id,p_favored_team,p_points,'ESPN',clock_timestamp())
 on conflict(game_id) do update set favored_team=excluded.favored_team,
 spread_points=excluded.spread_points,observed_at=excluded.observed_at
 where public.league_spreads.frozen_at is null;
end $$;
revoke all on function public.record_espn_spread(text,text,numeric) from public,anon,authenticated;
grant execute on function public.record_espn_spread(text,text,numeric) to service_role;
