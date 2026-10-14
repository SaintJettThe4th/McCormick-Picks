-- Read-only verification after the Week 6-8 kickoff migration.
select count(*) as total_games,
       count(*) filter (where kickoff_at is not null) as games_with_kickoff,
       count(*) filter (where kickoff_at is null) as games_without_kickoff
from public.league_games where season = 2026;

select week,
       count(*) as total_games,
       count(*) filter (where kickoff_at is not null) as games_with_kickoff
from public.league_games where week between 6 and 8
group by week order by week;

select id, away_team, home_team, kickoff_at
from public.tnf_games where week between 6 and 8 order by week;

select m.display_name, count(p.game_id) as picks
from public.league_members m
left join public.league_picks p on p.user_id = m.user_id
group by m.display_name order by m.display_name;
