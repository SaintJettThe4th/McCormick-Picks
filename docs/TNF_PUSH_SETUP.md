# McCormick Picks secure cutover checklist (PR #4: DRAFT)

**Not deployed, not end-to-end tested.** The live app remains unchanged.\n\n## Migration status (October 14, 2026)\n\n- Jett and Kevin activated in Supabase Auth and mapped to `league_members`.\n- 268 fixtures imported; only 1 kickoff populated, 267 require verification.\n- 158 historical picks verified against Weeks 1–5 comparison screenshots and imported: Jett 79, Kevin 79.\n- Historical import SQL corrected for Kevin Week 5 Broncos and Bears. Do not re-import as a substitute for verifying current DB state.\n- Secure mode is still disabled; no end-to-end authentication, pick lock or push test has passed.\n- NFL Week 6–8 matchups and kickoff times were checked against NFL schedule sources; a transactional SQL migration for 42 games is staged at `supabase/migrations/20261015_verified_weeks_6_8_kickoffs.sql` but HAS NOT BEEN RUN. It also stages Week 7 and 8 TNF reminder fixtures.\n- Before release: apply and verify the 42-game kickoff migration, verify remaining future games as they approach, test both identities and server RPC lock behavior on staging, deploy and test push scheduler.\n
Never merge or enable Supabase mode before verified migration.

## 1. Accounts and migration

1. Back up current app data from each browser (localStorage `picks` and
   `lockedPicks2026`) and compare with original messages. The checked-in
   `docs/historical-picks-review.json` contains **79 provisional picks per user**
   extracted from source, NOT a guaranteed historical truth. Review all entries.
2. In Supabase SQL Editor run
   `supabase/migrations/20261014_league_picks.sql`.
   (The earlier `20261014_tnf_reminders.sql` was already applied.)
3. In Authentication > URL Configuration add
   `https://saintjettthe4th.github.io/McCormick-Picks/auth-setup.html`
   to Redirect URLs. Once the setup page is deployed, set it as Site URL
   temporarily for dashboard-generated invitations. Invitation links must
   point to that page, not the current legacy app. **Do not invite yet.**
4. Deploy the staged auth setup page to a test deployment and create/activate
   Jett and Kevin as two distinct Supabase Auth accounts. Then assign the UUIDs
   manually using Supabase SQL Editor, substituting real IDs (do not share them):
   `insert into public.league_members(user_id,display_name) values
   ('<JETT_AUTH_UUID>','Jett'),('<KEVIN_AUTH_UUID>','Kevin');`
   Verify identity before assigning UUIDs.
5. Review `20261014_review_fixtures.sql` against the actual NFL schedule.
   Most kickoff times are deliberately NULL, so server submissions fail closed
   until verified timestamps are filled in. Run only after reviewing. It also
   inserts the Oct 15 SEA @ DEN TNF matchup (8:15 PM EDT).
6. **Only after comparing historical picks**, review and run
   `20261014_review_historical_import.sql`. It inserts without overwriting
   existing database picks. Compare every row against the verified backup.
   Do not automatically import browser auto-picks as user-confirmed picks.

## Security test preparation\n\nA rollback-only RPC test is staged at `supabase/tests/transactional_pick_security_smoke.sql`. It has not been executed. Run it only with a verified future kickoff and inspect its notices; a locked or unverified game produces an inconclusive result, not a pass.\n\n## 2. App cutover

7. In `supabase-config.js`, set `enableSupabaseMode: true` on a **test
   deployment** only after the above data checks pass. In secure mode,
   `supabase-integration.js` replaces client password checks, browser saves
   and automatic home picks with Supabase Auth and the
   `submit_league_pick` server RPC. Check both player identities and standings.
   **Do not activate in production until verified.**
8. Verify pre-kickoff saves, post-kickoff rejection, cross-user isolation,
   refresh/device consistency, historical standings and invalid team rejection.
   Test session expiration and failed network requests. Legacy mode retains
   known insecure browser-password behavior until cutover.

## 3. Web push and scheduler

9. Generate VAPID keys locally using a trusted tool. Put the PUBLIC key in
   `supabase-config.js` as `vapidPublicKey`. Store private VAPID key ONLY in
   Supabase Edge Function secrets. Also set `VAPID_SUBJECT` (mailto: address),
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (or the compatible server-only
   service-role credential), and a strong `REMINDER_CRON_SECRET`. Never commit
   private keys or tokens.
10. Deploy `supabase/functions/tnf-reminders/index.ts` as a protected Edge
    Function. Configure a trusted cron to POST every five minutes with the
    `x-reminder-secret` header, and do not expose the secret to browsers.
11. On each phone, log in and click **Enable TNF Notifications**. On iPhone,
    add the GitHub Pages app to Home Screen first, then opt in. Verify
    permission and saved subscription per user.
12. Test missing picks at noon America/New_York and 55–60 minutes before
    kickoff, saved picks suppressing both, no duplicate deliveries, revoked
    subscriptions, DST and flexed kickoffs. Delivery is best-effort; production
    retries/outbox remain future hardening. The reminder function reads
    `league_picks` (authoritative), never localStorage.

## Release rule

Keep PR #4 as DRAFT until steps 1–12 pass. Recommend **Squash and merge**
only after user approves and the production cutover has been verified.
