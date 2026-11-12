# ESPN spread sync deployment checklist

**Status: staged code only; not deployed.** No verified live ESPN spreads are currently guaranteed.

1. Apply `supabase/migrations/20261112_league_spreads.sql` in Supabase SQL Editor.
2. Deploy `supabase/functions/refresh-espn-spreads/index.ts` as the `refresh-espn-spreads` Edge Function with JWT verification enabled.
3. Configure a trusted scheduler to POST to that function every minute with `Authorization: Bearer <service-role key>`. Store the key only in server-side secrets; **never in GitHub Pages, browser JavaScript, or public SQL**.
4. Test ESPN's scoreboard odds payload for each active week and validate the exact displayed favorite and line against ESPN. The ESPN endpoint is unofficial and may omit odds or change format. In that case the app intentionally shows N/A.
5. Confirm new spreads update before kickoff, and that updates after kickoff are rejected by the SQL RPC. A missing spread stays N/A. EVEN is shown only for a confirmed zero-point spread.
6. Verify the game display, then merge the release PR after owner approval.

Browser display refreshes every 60 seconds while signed in. The trusted server job also needs to run for updates to reach Supabase when no one is online. The database function uses the server clock and rejects changes at/after kickoff. Spreads are informational only and never affect picks or scoring.

**ESPN licensing:** Check ESPN's terms and any permissions needed before operating a continuous production feed. This is not an official ESPN integration.
