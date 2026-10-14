// Deploy as a protected Edge Function; schedule a call every five minutes.
import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const env = (key: string) => Deno.env.get(key) ?? '';
const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false },
});
webpush.setVapidDetails(env('VAPID_SUBJECT'), env('VAPID_PUBLIC_KEY'), env('VAPID_PRIVATE_KEY'));

function easternParts(date: Date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/New_York', weekday: 'short', hour: '2-digit',
    minute: '2-digit', hour12: false,
  }).formatToParts(date);
  return Object.fromEntries(parts.map(p => [p.type, p.value]));
}

Deno.serve(async (req) => {
  if (req.method !== 'POST' || !env('REMINDER_CRON_SECRET') ||
      req.headers.get('x-reminder-secret') !== env('REMINDER_CRON_SECRET')) {
    return new Response('Unauthorized', { status: 401 });
  }
  const now = new Date();
  const et = easternParts(now);
  const isNoonWindow = et.weekday === 'Thu' && et.hour === '12' && Number(et.minute) < 5;
  const { data: games, error: gameError } = await db.from('tnf_games')
    .select('id,away_team,home_team,kickoff_at')
    .gt('kickoff_at', now.toISOString())
    .lte('kickoff_at', new Date(now.getTime() + 24 * 3600_000).toISOString());
  if (gameError) return new Response('Game lookup failed', { status: 500 });
  let sent = 0;
  for (const game of games ?? []) {
    const until = new Date(game.kickoff_at).getTime() - now.getTime();
    // Cron runs every five minutes. Accept a small window around the one-hour mark
    // so a delayed invocation does not silently miss the reminder.
    const oneHourWindow = until > 50 * 60_000 && until <= 60 * 60_000;
    const slot = oneHourWindow ? 'one_hour' : isNoonWindow ? 'noon' : null;
    if (!slot) continue;
    // Authenticated users who opted in are discovered by subscriptions.
    const { data: subscriptions, error: subError } = await db.from('push_subscriptions')
      .select('user_id,endpoint,subscription');
    if (subError) return new Response('Subscription lookup failed', { status: 500 });
    const byUser = new Map<string, NonNullable<typeof subscriptions>>();
    for (const sub of subscriptions ?? []) {
      const group = byUser.get(sub.user_id) ?? [];
      group.push(sub);
      byUser.set(sub.user_id, group);
    }
    for (const [userId, devices] of byUser) {
      const { data: existingPick, error: pickError } = await db.from('league_picks')
        .select('team').eq('game_id', game.id).eq('user_id', userId).maybeSingle();
      if (pickError || existingPick) continue; // Fail closed if pick status is uncertain.
      // Unique constraint prevents duplicate reminders for this user/game/slot.
      const { error: reserveError } = await db.from('tnf_reminder_deliveries')
        .insert({ game_id: game.id, user_id: userId, slot });
      if (reserveError) continue;
      const payload = JSON.stringify({
        title: 'McCormick Picks: TNF reminder',
        body: `Pick ${game.away_team} vs. ${game.home_team} before kickoff!`,
        url: '/McCormick-Picks/',
      });
      let deliveredToUser = 0;
      for (const device of devices ?? []) {
        try {
          await webpush.sendNotification(device.subscription, payload);
          sent++;
          deliveredToUser++;
        } catch (error) {
          const status = (error as { statusCode?: number }).statusCode;
          if (status === 404 || status === 410) {
            await db.from('push_subscriptions').delete().eq('endpoint', device.endpoint);
          } else console.error('Push delivery failed', status ?? 'unknown');
        }
      }
      // A reservation must not permanently suppress reminders if every device failed.
      // Keep successful deliveries deduplicated; retry failed-only deliveries next run.
      if (deliveredToUser === 0) {
        await db.from('tnf_reminder_deliveries').delete()
          .eq('game_id',game.id).eq('user_id',userId).eq('slot',slot);
      }
    }
  }
  return Response.json({ sent });
});
