-- Transactional proof that the server rejects a pick after kickoff.
-- Temporarily backdates ONE verified future fixture, then rolls everything back.
-- Run the whole script together in Supabase SQL Editor. No permanent edits.
begin;
create temporary table simulated_lock_results(test text,result text,detail text) on commit drop;
grant select,insert on simulated_lock_results to authenticated;

do $prepare$
declare v_id text;
begin
  select id into v_id from public.league_games
  where kickoff_at > clock_timestamp() + interval '5 minutes'
  order by kickoff_at limit 1;
  if v_id is null then
    raise exception 'No verified future fixture exists for simulated lock test';
  end if;
  perform set_config('mccormick.test_game_id',v_id,true);
  update public.league_games set kickoff_at=clock_timestamp()-interval '1 minute'
  where id=v_id;
end
$prepare$;

set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);
do $test$
declare v_id text := current_setting('mccormick.test_game_id');
        v_team text;
begin
  select home_team into v_team from public.league_games where id=v_id;
  begin
    perform public.submit_league_pick(v_id,v_team);
    insert into simulated_lock_results values('Simulated post-kickoff lock','FAIL','RPC accepted a pick for game '||v_id);
  exception when others then
    insert into simulated_lock_results values('Simulated post-kickoff lock',
      case when sqlerrm='Game locked' then 'PASS' else 'FAIL' end,
      'Game '||v_id||': '||sqlerrm);
  end;
end
$test$;
select test,result,detail from simulated_lock_results;
rollback;
