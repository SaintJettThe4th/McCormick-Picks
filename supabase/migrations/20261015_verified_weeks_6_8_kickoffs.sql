-- REVIEWED against the NFL official 2026 Week 6, 7 and 8 schedules (ET).
-- Sources: https://www.nfl.com/schedules/2026/by-week/week-6
-- https://nfl-ops-prod-umbraco-author.azurewebsites.net/calendar-events/nfl-schedule/2026-regular-season-schedule/
-- Source of truth for future kickoff times remains NFL; recheck flexes weekly.
-- Safe to rerun; changes ONLY existing fixtures whose home and away teams match.
-- DOES NOT alter any historical picks.
begin;
create temporary table verified_2026_kickoffs (
 id text primary key, home_team text not null, away_team text not null,
 kickoff_at timestamptz not null
) on commit drop;
insert into verified_2026_kickoffs(id,home_team,away_team,kickoff_at) values
  ('6-1','DEN','SEA','2026-10-16T00:15:00.000Z'),
  ('6-2','JAX','HOU','2026-10-18T13:30:00.000Z'),
  ('6-3','ATL','CHI','2026-10-18T17:00:00.000Z'),
  ('6-4','CLE','BAL','2026-10-18T17:00:00.000Z'),
  ('6-5','IND','TEN','2026-10-18T17:00:00.000Z'),
  ('6-6','NE','NYJ','2026-10-18T17:00:00.000Z'),
  ('6-7','NYG','NO','2026-10-18T17:00:00.000Z'),
  ('6-8','PHI','CAR','2026-10-18T17:00:00.000Z'),
  ('6-9','LAR','ARI','2026-10-18T20:05:00.000Z'),
  ('6-10','KC','LAC','2026-10-18T20:25:00.000Z'),
  ('6-11','LV','BUF','2026-10-18T20:25:00.000Z'),
  ('6-12','GB','DAL','2026-10-19T00:20:00.000Z'),
  ('6-13','SF','WAS','2026-10-20T00:15:00.000Z'),
  ('6-14','TB','PIT','2026-10-18T17:00:00.000Z'),
  ('7-1','CHI','NE','2026-10-23T00:15:00.000Z'),
  ('7-2','NO','PIT','2026-10-25T13:30:00.000Z'),
  ('7-3','TEN','CLE','2026-10-25T17:00:00.000Z'),
  ('7-4','NYJ','MIA','2026-10-25T17:00:00.000Z'),
  ('7-5','MIN','IND','2026-10-25T17:00:00.000Z'),
  ('7-6','BAL','CIN','2026-10-25T17:00:00.000Z'),
  ('7-7','HOU','NYG','2026-10-25T17:00:00.000Z'),
  ('7-8','CAR','TB','2026-10-25T17:00:00.000Z'),
  ('7-9','ATL','SF','2026-10-25T17:00:00.000Z'),
  ('7-10','ARI','DEN','2026-10-25T20:05:00.000Z'),
  ('7-11','LV','LAR','2026-10-25T20:25:00.000Z'),
  ('7-12','DET','GB','2026-10-25T20:25:00.000Z'),
  ('7-13','SEA','KC','2026-10-26T00:20:00.000Z'),
  ('7-14','PHI','DAL','2026-10-27T00:15:00.000Z'),
  ('8-1','GB','CAR','2026-10-30T00:15:00.000Z'),
  ('8-2','CIN','TEN','2026-11-01T18:00:00.000Z'),
  ('8-3','JAX','IND','2026-11-01T18:00:00.000Z'),
  ('8-4','PIT','CLE','2026-11-01T18:00:00.000Z'),
  ('8-5','BUF','BAL','2026-11-01T18:00:00.000Z'),
  ('8-6','TB','ATL','2026-11-01T18:00:00.000Z'),
  ('8-7','DET','MIN','2026-11-01T18:00:00.000Z'),
  ('8-8','DAL','ARI','2026-11-01T18:00:00.000Z'),
  ('8-9','NYJ','LV','2026-11-01T18:00:00.000Z'),
  ('8-10','LAR','LAC','2026-11-01T21:05:00.000Z'),
  ('8-11','DEN','KC','2026-11-01T21:25:00.000Z'),
  ('8-12','MIA','NE','2026-11-01T21:25:00.000Z'),
  ('8-13','WAS','PHI','2026-11-02T01:20:00.000Z'),
  ('8-14','SEA','CHI','2026-11-03T01:15:00.000Z');
do $$
declare mismatches integer;
begin
 select count(*) into mismatches from verified_2026_kickoffs v
 left join public.league_games g on g.id=v.id
 where g.id is null or g.home_team<>v.home_team or g.away_team<>v.away_team;
 if mismatches>0 then raise exception 'Fixture mismatch: % rows; no changes committed',mismatches; end if;
end $$;
update public.league_games g set kickoff_at=v.kickoff_at
from verified_2026_kickoffs v where g.id=v.id
and g.home_team=v.home_team and g.away_team=v.away_team;
-- Add upcoming Thursday reminders only for NFL-confirmed TNF matchups.
insert into public.tnf_games(id,away_team,home_team,kickoff_at,season,week)
select g.id,g.away_team,g.home_team,g.kickoff_at,g.season,g.week
from public.league_games g where g.id in ('6-1','7-1','8-1')
on conflict (id) do update set kickoff_at=excluded.kickoff_at,
  away_team=excluded.away_team,home_team=excluded.home_team;
-- Align reminder fixture with authoritative league game.
update public.tnf_games t set kickoff_at=g.kickoff_at
from public.league_games g where t.id=g.id and t.id in (select id from verified_2026_kickoffs);
commit;
