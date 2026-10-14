-- Apply AFTER the initial TNF schema. Empty tables; no existing picks are changed.
create table if not exists public.league_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null unique check (display_name in ('Jett','Kevin'))
);
create table if not exists public.league_games (
 id text primary key,
 home_team text not null,
 away_team text not null,
 kickoff_at timestamptz,
 season integer not null default 2026,
 week integer not null,
 check (home_team <> away_team)
);
create table if not exists public.league_picks (
 game_id text not null references public.league_games(id),
 user_id uuid not null references auth.users(id),
 team text not null,
 submitted_at timestamptz not null default now(),
 primary key (game_id,user_id)
);
alter table public.league_members enable row level security;
alter table public.league_games enable row level security;
alter table public.league_picks enable row level security;
create policy "members read own membership" on public.league_members
 for select to authenticated using (user_id=auth.uid());
create policy "members read games" on public.league_games
 for select to authenticated using (exists (select 1 from public.league_members m where m.user_id=auth.uid()));
create policy "members read league picks" on public.league_picks
 for select to authenticated using (exists (select 1 from public.league_members m where m.user_id=auth.uid()));
-- Browser clients get NO insert/update/delete policy on games, picks, or membership.
create or replace function public.submit_league_pick(p_game_id text, p_team text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_game public.league_games%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.league_members where user_id=auth.uid()) then
  raise exception 'Not a league member';
 end if;
 -- Serialize against concurrent changes for this game; prevent races around edits.
 select * into v_game from public.league_games where id=p_game_id for update;
 if not found then raise exception 'Unknown game'; end if;
 if v_game.kickoff_at is null then raise exception 'Kickoff not verified'; end if;
 if clock_timestamp() >= v_game.kickoff_at then raise exception 'Game locked'; end if;
 if p_team not in (v_game.home_team,v_game.away_team) then raise exception 'Invalid team'; end if;
 insert into public.league_picks(game_id,user_id,team,submitted_at)
 values (p_game_id,auth.uid(),p_team,clock_timestamp())
 on conflict (game_id,user_id) do update
 set team=excluded.team,submitted_at=excluded.submitted_at;
end $$;
revoke all on function public.submit_league_pick(text,text) from public,anon;
grant execute on function public.submit_league_pick(text,text) to authenticated;
-- Historical imports are performed separately by an administrator AFTER verification,
-- never by the browser and never by calling submit_league_pick for past games.
