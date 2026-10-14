# Thursday Night Football push reminders (not yet active)

This PR adds the **backend schema, scheduled reminder handler, and push service worker**.
It deliberately does **not** activate notifications or change existing picks. The app
currently authenticates with client-side passwords and stores picks in localStorage,
which cannot securely establish identity or serve as a reliable source of truth.

## Required before activation

1. Create a Supabase project. Enable Supabase Auth for Jett and Kevin, with distinct
   auth accounts. Do not reuse the current client-side passwords as database credentials.
2. Back up and reconcile all historic picks, then migrate **authoritative picks** to
   `tnf_picks` and the actual Thursday games/kickoffs to `tnf_games`. Never infer a
   missing pick from localStorage. Ensure the server-side pick submission endpoint
   enforces kickoff locks; client-side controls are not enough.
3. Run `supabase/migrations/20261014_tnf_reminders.sql` in the project. Provision
   future TNF games using verified kickoff timestamps in UTC, including any flexed
   schedule changes. The scheduler uses `America/New_York` for noon and kickoff
   timestamps for the one-hour reminder.
4. Generate VAPID keys and configure Edge Function secrets:
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `VAPID_PUBLIC_KEY`,
   `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `REMINDER_CRON_SECRET`.
   Never commit any secret or service-role key to GitHub or browser code.
5. Deploy `tnf-reminders` as a protected Supabase Edge Function. Configure a
   trusted server-side scheduler to POST every five minutes with the
   `x-reminder-secret` header. Do not make the endpoint public.
6. After secure auth is integrated into the app, add an explicit **Enable
   Notifications** button that requests permission on user interaction, registers
   `/McCormick-Picks/push-sw.js`, subscribes using the public VAPID key, and
   saves the subscription via Supabase Auth/RLS as that user. Support unsubscribe.
   iOS web push requires installation to the Home Screen and user permission.
7. Test: no pick => noon ET and one-hour reminders; saved pick => no reminder;
   Jett/Kevin isolated; duplicate scheduler invocation => one slot; DST, missed
   windows, changed kickoffs, revoked subscriptions, and permission denial.

## Delivery limitations

Delivery is best-effort; operating systems may delay/suppress notifications.
The unique delivery reservation avoids duplicates, but a transient send failure
can consume the slot without a delivered notification. Production should use an
outbox with retry state and per-device delivery records. Existing in-app alerts
are unchanged. **Do not merge expecting working push notifications immediately.**
