-- Week 9 2026 kickoffs. Cross-checked against NFL.com Week 9 and ESPN Week 9.
-- Run in Supabase SQL Editor as a SINGLE statement batch.
-- Safety: verifies every ID, pairing, existing timestamp, then fills missing kickoffs.
-- Never modifies any existing pick or an already-set kickoff timestamp.
BEGIN;
CREATE TEMP TABLE expected_week9 (
 id text PRIMARY KEY, home_team text, away_team text, kickoff_at timestamptz
) ON COMMIT DROP;
INSERT INTO expected_week9 (id,home_team,away_team,kickoff_at) VALUES
 ('9-1','BAL','JAX','2026-11-06T01:15:00Z'::timestamptz),
 ('9-2','ATL','CIN','2026-11-08T14:30:00Z'::timestamptz),
 ('9-3','NO','CLE','2026-11-08T18:00:00Z'::timestamptz),
 ('9-4','IND','DAL','2026-11-08T18:00:00Z'::timestamptz),
 ('9-5','CAR','DEN','2026-11-08T18:00:00Z'::timestamptz),
 ('9-6','MIA','DET','2026-11-08T18:00:00Z'::timestamptz),
 ('9-7','WAS','LAR','2026-11-08T18:00:00Z'::timestamptz),
 ('9-8','PHI','NYG','2026-11-08T18:00:00Z'::timestamptz),
 ('9-9','KC','NYJ','2026-11-08T18:00:00Z'::timestamptz),
 ('9-10','LAC','HOU','2026-11-08T21:05:00Z'::timestamptz),
 ('9-11','SF','LV','2026-11-08T21:25:00Z'::timestamptz),
 ('9-12','SEA','ARI','2026-11-08T21:25:00Z'::timestamptz),
 ('9-13','NE','GB','2026-11-08T21:25:00Z'::timestamptz),
 ('9-14','CHI','TB','2026-11-09T01:20:00Z'::timestamptz),
 ('9-15','MIN','BUF','2026-11-10T01:15:00Z'::timestamptz);
DO $verify$
DECLARE mismatch_count integer;
BEGIN
 SELECT count(*) INTO mismatch_count
 FROM expected_week9 e LEFT JOIN public.league_games g ON g.id=e.id AND g.season=2026 AND g.week=9
 WHERE g.id IS NULL OR g.home_team<>e.home_team OR g.away_team<>e.away_team
    OR (g.kickoff_at IS NOT NULL AND g.kickoff_at<>e.kickoff_at);
 IF mismatch_count<>0 THEN
   RAISE EXCEPTION 'Week 9 schedule mismatch (% games). Nothing changed. Inspect fixtures before retrying.',mismatch_count;
 END IF;
END $verify$;
UPDATE public.league_games g SET kickoff_at=e.kickoff_at
FROM expected_week9 e
WHERE g.id=e.id AND g.season=2026 AND g.week=9 AND g.kickoff_at IS NULL;
SELECT g.id,g.away_team,g.home_team,g.kickoff_at,
 CASE WHEN clock_timestamp()>=g.kickoff_at THEN 'LOCKED' ELSE 'UPCOMING' END AS status
FROM public.league_games g JOIN expected_week9 e ON g.id=e.id
ORDER BY g.kickoff_at,g.id;
COMMIT;
