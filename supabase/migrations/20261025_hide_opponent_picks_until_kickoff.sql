-- Prevent either player from querying the other's future picks via the Data API.
-- Preserve historical imported Weeks 1-5, whose kickoff timestamps were not populated.
-- Own picks remain readable at any time; opponent picks become readable after kickoff.
-- Run in Supabase SQL Editor after restoring the project.
begin;
drop policy if exists "members read league picks" on public.league_picks;
create policy "members read own and revealed opponent picks"
 on public.league_picks for select to authenticated
 using (
   exists (select 1 from public.league_members m where m.user_id = auth.uid())
   and (
     user_id = auth.uid()
     or exists (
       select 1 from public.league_games g
       where g.id = game_id
         and (g.week <= 5 and g.season = 2026
              or (g.kickoff_at is not null and clock_timestamp() >= g.kickoff_at))
     )
   )
 );
commit;
