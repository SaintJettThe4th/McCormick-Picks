# Secure preview release gate

This release branch was created from the current main branch to avoid merging the diverged `feature/tnf-push-reminder-foundation` branch directly.

## Confirmed manual checks (November 8, 2026)
- Jett selected Bears and Bills in the secure preview; both saved to Supabase and persisted after refresh.
- After removing hardcoded legacy credentials and embedded historical picks, both selections still persisted.
- Four read-only opponent-pick privacy SQL checks returned PASS.

## Verified historical import (user-confirmed November 8, 2026)
- User ran guarded SQL import of 114 picks from their screenshot: 57 each for Jett and Kevin, Weeks 6–9.
- User confirmed the eight verification rows matched the expected weekly counts (14, 14, 14, 15 per player).
- The import rejects any conflicting existing pick and does not silently overwrite saved choices.

- User confirmed the secure preview displays both players' imported Weeks 6–9 picks correctly.

## Must pass before production cutover
- [ ] Verify every remaining 2026 kickoff against ESPN and NFL.com; install verified timestamps in Supabase. Never guess kickoff times.
- [x] Read-only opponent-pick privacy test: four PASS results (user-confirmed).
- [x] Existing post-kickoff lock test: PASS (user-confirmed; rollback-only).
- [ ] Re-run privacy and lock tests after any further kickoff timestamp updates.
- [ ] Confirm Kevin can authenticate and save his own pick, without sharing his password.
- [ ] Audit all app links, navigation, scoring, weekly results, and picks history against authoritative Supabase data.
- [ ] Confirm old client-side password paths cannot be used for authentication in the production entrypoint.
- [ ] Decide whether TNF push notifications are in scope. They are **not yet configured**; do not advertise them as live.
- [ ] Obtain explicit owner approval before replacing the live `index.html` or merging this release PR.

## Cutover strategy
Keep `secure-preview/` operational during verification. Promote the reviewed Supabase-backed experience into the production entrypoint in a separate, auditable commit on this branch, then test it before merging. Do not merge the diverged old feature branch wholesale. Preserve an easy rollback path to the current production commit.
