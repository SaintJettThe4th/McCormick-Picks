-- READ-ONLY migration audit. Safe to run in Supabase SQL Editor.
-- Expected: 268 games; 158 picks; 79 each; 0 invalid team selections.
select count(*) as games, count(*) filter (where kickoff_at is not null) as verified_kickoffs
from public.league_games where season=2026;

select m.display_name, count(p.game_id) as picks
from public.league_members m left join public.league_picks p on p.user_id=m.user_id
group by m.display_name order by m.display_name;

select m.display_name, p.game_id, p.team, g.away_team, g.home_team
from public.league_picks p
join public.league_members m on m.user_id=p.user_id
join public.league_games g on g.id=p.game_id
where p.team not in (g.away_team,g.home_team)
order by m.display_name,p.game_id;

-- A kickoff is not considered verified merely because it is present.
-- Check all upcoming kickoffs against official NFL information before cutover.
select id,week,away_team,home_team,kickoff_at
from public.league_games
where season=2026 and kickoff_at is null
order by week,id;
