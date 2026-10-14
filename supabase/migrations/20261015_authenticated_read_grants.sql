-- Grant only the read permissions needed by the authenticated app.
-- Row-level security remains enabled and continues to filter rows.
-- No browser write privileges are granted to games, picks, or membership.
begin;
grant usage on schema public to authenticated;
grant select on public.league_members to authenticated;
grant select on public.league_games to authenticated;
grant select on public.league_picks to authenticated;
grant select on public.tnf_games to authenticated;
grant select, insert, delete on public.push_subscriptions to authenticated;
-- Allow UPDATE/DELETE only where an RLS policy explicitly permits it.
revoke insert, update, delete on public.league_members from authenticated;
revoke insert, update, delete on public.league_games from authenticated;
revoke insert, update, delete on public.league_picks from authenticated;
commit;
