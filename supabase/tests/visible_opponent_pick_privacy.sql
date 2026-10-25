-- Run AFTER applying 20261025_hide_opponent_picks_until_kickoff.sql.
-- Read-only verification; returns one row per check. No picks are modified.
-- The test queries as Jett and verifies the new policy is installed.
begin;
create temporary table privacy_test_results (test text, result text, detail text) on commit drop;
grant select, insert on privacy_test_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);

do $test$
declare
  v_policy_count int;
  v_leaks int;
  v_own_count int;
  v_historical int;
begin
  select count(*) into v_policy_count from pg_policies
    where schemaname='public' and tablename='league_picks'
      and policyname='members read own and revealed opponent picks';
  insert into privacy_test_results values ('Privacy policy installed',
    case when v_policy_count=1 then 'PASS' else 'FAIL' end,
    'Expected 1 policy, found ' || v_policy_count);

  select count(*) into v_leaks from public.league_picks p
    join public.league_games g on g.id=p.game_id
    where p.user_id <> auth.uid() and g.kickoff_at > clock_timestamp();
  insert into privacy_test_results values ('Future opponent picks hidden',
    case when v_leaks=0 then 'PASS' else 'FAIL' end,
    'Visible future opponent picks: ' || v_leaks);

  select count(*) into v_own_count from public.league_picks p where p.user_id=auth.uid();
  insert into privacy_test_results values ('Own picks readable',
    case when v_own_count>0 then 'PASS' else 'FAIL' end,
    'Own picks visible: ' || v_own_count);

  select count(*) into v_historical from public.league_picks p
    join public.league_games g on g.id=p.game_id
    where p.user_id <> auth.uid() and g.season=2026 and g.week <= 5;
  insert into privacy_test_results values ('Historical opponent picks readable',
    case when v_historical>0 then 'PASS' else 'FAIL' end,
    'Historical opponent picks visible: ' || v_historical);
end $test$;
select * from privacy_test_results order by test;
rollback;
