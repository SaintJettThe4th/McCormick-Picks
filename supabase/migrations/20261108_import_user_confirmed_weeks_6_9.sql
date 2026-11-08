-- User-provided screenshot import for Weeks 6-9, 2026 (Jett and Kevin).
-- Each pick matched to fixture ID and checked against known home/away teams.
-- ADMINISTRATIVE historical import only: run in Supabase SQL Editor as project owner.
-- This bypasses normal kickoff locking intentionally. Browser users cannot run this.
-- Protects against accidental overwrites: if any existing pick differs, aborts the
-- entire transaction and lists nothing changed. Existing matching picks stay untouched.
BEGIN;
CREATE TEMP TABLE screenshot_picks (display_name text NOT NULL, game_id text NOT NULL, team text NOT NULL, PRIMARY KEY(display_name,game_id)) ON COMMIT DROP;
INSERT INTO screenshot_picks(display_name,game_id,team) VALUES
 ('Jett','6-1','SEA'),
 ('Jett','6-2','JAX'),
 ('Jett','6-3','ATL'),
 ('Jett','6-4','BAL'),
 ('Jett','6-5','IND'),
 ('Jett','6-6','NE'),
 ('Jett','6-7','NO'),
 ('Jett','6-8','CAR'),
 ('Jett','6-9','LAR'),
 ('Jett','6-10','KC'),
 ('Jett','6-11','BUF'),
 ('Jett','6-12','GB'),
 ('Jett','6-13','SF'),
 ('Jett','6-14','PIT'),
 ('Jett','7-1','CHI'),
 ('Jett','7-2','NO'),
 ('Jett','7-3','CLE'),
 ('Jett','7-4','NYJ'),
 ('Jett','7-5','MIN'),
 ('Jett','7-6','BAL'),
 ('Jett','7-7','HOU'),
 ('Jett','7-8','CAR'),
 ('Jett','7-9','SF'),
 ('Jett','7-10','DEN'),
 ('Jett','7-11','LAR'),
 ('Jett','7-12','DET'),
 ('Jett','7-13','KC'),
 ('Jett','7-14','DAL'),
 ('Jett','8-1','GB'),
 ('Jett','8-2','CIN'),
 ('Jett','8-3','JAX'),
 ('Jett','8-4','CLE'),
 ('Jett','8-5','BUF'),
 ('Jett','8-6','ATL'),
 ('Jett','8-7','DET'),
 ('Jett','8-8','DAL'),
 ('Jett','8-9','LV'),
 ('Jett','8-10','LAR'),
 ('Jett','8-11','KC'),
 ('Jett','8-12','NE'),
 ('Jett','8-13','WAS'),
 ('Jett','8-14','SEA'),
 ('Jett','9-1','JAX'),
 ('Jett','9-2','CIN'),
 ('Jett','9-3','NO'),
 ('Jett','9-4','DAL'),
 ('Jett','9-5','DEN'),
 ('Jett','9-6','DET'),
 ('Jett','9-7','LAR'),
 ('Jett','9-8','NYG'),
 ('Jett','9-9','KC'),
 ('Jett','9-10','HOU'),
 ('Jett','9-11','SF'),
 ('Jett','9-12','SEA'),
 ('Jett','9-13','NE'),
 ('Jett','9-14','CHI'),
 ('Jett','9-15','BUF'),
 ('Kevin','6-1','SEA'),
 ('Kevin','6-2','JAX'),
 ('Kevin','6-3','CHI'),
 ('Kevin','6-4','BAL'),
 ('Kevin','6-5','IND'),
 ('Kevin','6-6','NE'),
 ('Kevin','6-7','NO'),
 ('Kevin','6-8','CAR'),
 ('Kevin','6-9','LAR'),
 ('Kevin','6-10','KC'),
 ('Kevin','6-11','BUF'),
 ('Kevin','6-12','GB'),
 ('Kevin','6-13','SF'),
 ('Kevin','6-14','PIT'),
 ('Kevin','7-1','CHI'),
 ('Kevin','7-2','NO'),
 ('Kevin','7-3','CLE'),
 ('Kevin','7-4','NYJ'),
 ('Kevin','7-5','MIN'),
 ('Kevin','7-6','CIN'),
 ('Kevin','7-7','HOU'),
 ('Kevin','7-8','CAR'),
 ('Kevin','7-9','SF'),
 ('Kevin','7-10','DEN'),
 ('Kevin','7-11','LV'),
 ('Kevin','7-12','GB'),
 ('Kevin','7-13','SEA'),
 ('Kevin','7-14','DAL'),
 ('Kevin','8-1','CAR'),
 ('Kevin','8-2','CIN'),
 ('Kevin','8-3','JAX'),
 ('Kevin','8-4','PIT'),
 ('Kevin','8-5','BUF'),
 ('Kevin','8-6','TB'),
 ('Kevin','8-7','DET'),
 ('Kevin','8-8','DAL'),
 ('Kevin','8-9','LV'),
 ('Kevin','8-10','LAR'),
 ('Kevin','8-11','KC'),
 ('Kevin','8-12','NE'),
 ('Kevin','8-13','WAS'),
 ('Kevin','8-14','SEA'),
 ('Kevin','9-1','JAX'),
 ('Kevin','9-2','CIN'),
 ('Kevin','9-3','NO'),
 ('Kevin','9-4','DAL'),
 ('Kevin','9-5','DEN'),
 ('Kevin','9-6','DET'),
 ('Kevin','9-7','LAR'),
 ('Kevin','9-8','NYG'),
 ('Kevin','9-9','KC'),
 ('Kevin','9-10','HOU'),
 ('Kevin','9-11','SF'),
 ('Kevin','9-12','SEA'),
 ('Kevin','9-13','GB'),
 ('Kevin','9-14','CHI'),
 ('Kevin','9-15','BUF');
DO $audit$
DECLARE bad int;
BEGIN
 IF (SELECT count(*) FROM screenshot_picks) <> 114 THEN
  RAISE EXCEPTION 'Expected 114 screenshot picks (57 games x 2 people)';
 END IF;
 SELECT count(*) INTO bad FROM screenshot_picks s
 LEFT JOIN public.league_members m ON m.display_name=s.display_name
 LEFT JOIN public.league_games g ON g.id=s.game_id
 WHERE m.user_id IS NULL OR g.id IS NULL OR g.season<>2026 OR g.week NOT BETWEEN 6 AND 9
 OR s.team NOT IN (g.home_team,g.away_team);
 IF bad>0 THEN RAISE EXCEPTION 'Invalid member, fixture or team: % entries; no changes made',bad; END IF;
 SELECT count(*) INTO bad FROM screenshot_picks s
 JOIN public.league_members m ON m.display_name=s.display_name
 JOIN public.league_picks p ON p.user_id=m.user_id AND p.game_id=s.game_id
 WHERE p.team<>s.team;
 IF bad>0 THEN RAISE EXCEPTION 'Found % existing picks that differ from screenshot. No changes made; review before any overwrite.',bad; END IF;
END $audit$;
INSERT INTO public.league_picks(game_id,user_id,team)
SELECT s.game_id,m.user_id,s.team
FROM screenshot_picks s JOIN public.league_members m ON m.display_name=s.display_name
ON CONFLICT (game_id,user_id) DO NOTHING;
SELECT m.display_name,g.week,count(*) AS picks_recorded
FROM public.league_picks p JOIN public.league_members m ON m.user_id=p.user_id
JOIN public.league_games g ON g.id=p.game_id
WHERE g.season=2026 AND g.week BETWEEN 6 AND 9
GROUP BY m.display_name,g.week ORDER BY m.display_name,g.week;
COMMIT;
