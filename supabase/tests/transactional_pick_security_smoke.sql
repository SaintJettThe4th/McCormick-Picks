-- TRANSACTIONAL SECURITY SMOKE TEST. Everything is rolled back.
-- Run only after a verified future kickoff exists in league_games.
-- This test does not persist or overwrite any historical picks.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);

-- Membership must identify Jett.
select auth.uid() as test_user, display_name
from public.league_members where user_id=auth.uid();

-- Test a deliberate invalid team: it must be rejected by submit_league_pick.
do $$
begin
  begin
    perform public.submit_league_pick('6-1','NOT_A_TEAM');
    raise exception 'SECURITY TEST FAILED: invalid team accepted';
  exception
    when others then
      if sqlerrm = 'Invalid team' then
        raise notice 'PASS: invalid team rejected';
      elsif sqlerrm = 'Kickoff not verified' or sqlerrm = 'Game locked' then
        raise notice 'INCONCLUSIVE: game locked/unverified; rerun with a verified future game';
      else
        raise;
      end if;
  end;
end $$;
rollback;
