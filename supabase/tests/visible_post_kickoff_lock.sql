-- Visible, rollback-only test that a past kickoff cannot be picked.
-- Uses authenticated Jett identity. Never modifies stored picks.
begin;
create temporary table lock_test_results(test text,result text,detail text) on commit drop;
grant select,insert on lock_test_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);

do $test$
declare v_game public.league_games%rowtype;
begin
  select * into v_game from public.league_games
  where kickoff_at is not null and kickoff_at <= clock_timestamp()
  order by kickoff_at desc limit 1;
  if not found then
    insert into lock_test_results values('Post-kickoff lock','SKIP','No verified game has kicked off yet');
    return;
  end if;
  begin
    perform public.submit_league_pick(v_game.id,v_game.home_team);
    insert into lock_test_results values('Post-kickoff lock','FAIL','RPC accepted pick for locked game '||v_game.id);
  exception when others then
    insert into lock_test_results values('Post-kickoff lock',
      case when sqlerrm='Game locked' then 'PASS' else 'FAIL' end,
      'Game '||v_game.id||': '||sqlerrm);
  end;
end
$test$;
select test,result,detail from lock_test_results;
rollback;
