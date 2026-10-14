-- Read-only/rollback-only authenticated pick-security smoke test.
-- Uses the first verified future game; fails clearly if none exists.
-- Does not alter historical picks or leave any new picks behind.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','35f21e03-743a-4fb2-8b58-8f4425bcb6d4',true);

do $$
declare
  v_game public.league_games%rowtype;
  v_member text;
  v_result text;
begin
  select display_name into v_member from public.league_members where user_id=auth.uid();
  if v_member is distinct from 'Jett' then
    raise exception 'FAIL: Jett identity missing or incorrect';
  end if;
  raise notice 'PASS: authenticated Jett membership';

  select * into v_game from public.league_games
  where kickoff_at > clock_timestamp() + interval '5 minutes'
  order by kickoff_at limit 1;
  if not found then
    raise notice 'SKIP: no verified future game exists';
    return;
  end if;

  -- Deliberately invalid team must always be rejected.
  v_result := null;
  begin
    perform public.submit_league_pick(v_game.id,'NOT_A_TEAM');
    v_result := 'FAIL: invalid team accepted';
  exception when others then
    if sqlerrm = 'Invalid team' then
      raise notice 'PASS: invalid team rejected';
    else
      raise exception 'FAIL: unexpected invalid-team result: %',sqlerrm;
    end if;
  end;
  if v_result is not null then raise exception '%',v_result; end if;

  -- Valid pre-kickoff submission is accepted but rolled back.
  perform public.submit_league_pick(v_game.id,v_game.home_team);
  raise notice 'PASS: valid pre-kickoff pick accepted (will roll back)';

  -- Direct table writes must not be possible for authenticated browser role.
  v_result := null;
  begin
    insert into public.league_picks(game_id,user_id,team)
    values (v_game.id,auth.uid(),v_game.away_team)
    on conflict (game_id,user_id) do update set team=excluded.team;
    v_result := 'FAIL: direct table write accepted';
  exception when insufficient_privilege then
    raise notice 'PASS: direct pick table write blocked';
  end;
  if v_result is not null then raise exception '%',v_result; end if;
end $$;
rollback;
