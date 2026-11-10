-- Correct Kevin's confirmed Week 7 selection: Pittsburgh Steelers over New Orleans Saints.
-- Administrative correction for an already-locked historical game.
-- Exactly one existing pick must match the old value, or the transaction aborts.
BEGIN;
DO $$
DECLARE affected integer;
BEGIN
 UPDATE public.league_picks p
 SET team='PIT'
 FROM public.league_members m, public.league_games g
 WHERE p.user_id=m.user_id AND p.game_id=g.id
   AND m.display_name='Kevin' AND g.id='7-2'
   AND g.season=2026 AND g.week=7
   AND g.home_team='NO' AND g.away_team='PIT'
   AND p.team='NO';
 GET DIAGNOSTICS affected = ROW_COUNT;
 IF affected<>1 THEN
   RAISE EXCEPTION 'Expected exactly one Kevin Week 7 Saints pick; found %. No change made.', affected;
 END IF;
END $$;
SELECT m.display_name,g.week,g.id,g.away_team,g.home_team,p.team AS saved_pick
FROM public.league_picks p
JOIN public.league_members m ON m.user_id=p.user_id
JOIN public.league_games g ON g.id=p.game_id
WHERE g.id='7-2' ORDER BY m.display_name;
COMMIT;
