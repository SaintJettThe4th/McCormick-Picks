-- Single-result security test for Supabase SQL Editor.
-- Returns visible rows instead of NOTICE messages. Everything rolls back.
-- Run the ENTIRE script, not a selected statement.
begin;
create temporary table security_test_results (
  test text not null,
  result text not null,
  detail text
) on commit drop;
grant select, insert on security_test_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);

do $test$
declare
  v_game public.league_games%rowtype;
  v_name text;
  v_error text;
begin
  begin
    select display_name into v_name from public.league_members where user_id=auth.uid();
    insert into security_test_results values
      ('Jett membership',case when v_name='Jett' then 'PASS' else 'FAIL' end,coalesce(v_name,'No member found'));
  exception when others then
    insert into security_test_results values ('Jett membership','FAIL',sqlerrm);
  end;

  begin
    select * into v_game from public.league_games
    where kickoff_at > clock_timestamp() + interval '5 minutes'
    order by kickoff_at limit 1;
    if not found then
      insert into security_test_results values ('Future fixture','SKIP','No verified future kickoff available');
      return;
    end if;
    insert into security_test_results values ('Future fixture','PASS',v_game.id);
  exception when others then
    insert into security_test_results values ('Future fixture','FAIL',sqlerrm);
    return;
  end;

  begin
    perform public.submit_league_pick(v_game.id,'NOT_A_TEAM');
    insert into security_test_results values ('Invalid team rejected','FAIL','RPC accepted NOT_A_TEAM');
  exception when others then
    get stacked diagnostics v_error = message_text;
    insert into security_test_results values ('Invalid team rejected',
      case when v_error='Invalid team' then 'PASS' else 'FAIL' end,v_error);
  end;

  begin
    perform public.submit_league_pick(v_game.id,v_game.home_team);
    insert into security_test_results values ('Valid future pick','PASS','RPC accepted; will roll back');
  exception when others then
    insert into security_test_results values ('Valid future pick','FAIL',sqlerrm);
  end;

  begin
    insert into public.league_picks(game_id,user_id,team)
    values(v_game.id,auth.uid(),v_game.away_team)
    on conflict (game_id,user_id) do update set team=excluded.team;
    insert into security_test_results values ('Direct pick write blocked','FAIL','Direct write was allowed');
  exception when insufficient_privilege then
    insert into security_test_results values ('Direct pick write blocked','PASS','Permission denied as expected');
  when others then
    insert into security_test_results values ('Direct pick write blocked','FAIL',sqlerrm);
  end;
end
$test$;

-- Show the actual results as the final SELECT.
select test,result,detail from security_test_results order by test;
rollback;
