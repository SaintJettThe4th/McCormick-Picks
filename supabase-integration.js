// Opt-in cutover: legacy behavior is unchanged until enabled explicitly.
// Activate only AFTER both accounts, fixtures and historical picks are verified.
import { supabaseClient as db } from './supabase-client.js';
const cfg = window.MCCORMICK_SUPABASE_CONFIG;
if (cfg?.enableSupabaseMode === true) {
  if (!db) throw new Error('Supabase mode enabled without a valid public client configuration.');
  const nameByUser = new Map();
  const status = (message) => {
    let node = document.getElementById('supabase-status');
    if (!node) {
      node = document.createElement('p');
      node.id = 'supabase-status';
      node.style.cssText = 'color:#f3cd74;font-size:13px;margin:8px 0;';
      document.getElementById('password-form').appendChild(node);
    }
    node.textContent = message;
  };
  const email = document.createElement('input');
  email.type = 'email';
  email.id = 'supabase-email';
  email.placeholder = 'Email address';
  email.autocomplete = 'username';
  email.required = true;
  email.style.cssText = 'box-sizing:border-box;width:100%;padding:12px;margin-bottom:8px;border-radius:10px;';
  document.getElementById('password-input').before(email);
  document.getElementById('password-input').autocomplete = 'current-password';

  const baseLogout = app.logout.bind(app);
  const baseSelectUser = app.selectUser.bind(app);

  // Never synthesize historical selections or save them to localStorage in secure mode.
  app.loadPicks = () => {};
  app.autoPickLockedGames = () => {};
  app.savePicks = () => {};
  app.passwords = Object.create(null);

  async function loadAuthoritativePicks() {
    const [{data:members,error:membersError},{data:rows,error:picksError}] = await Promise.all([
      db.from('league_members').select('user_id,display_name'),
      db.from('league_picks').select('game_id,user_id,team'),
    ]);
    if (membersError || picksError) throw membersError || picksError;
    for (const name of ['Jett','Kevin']) {
      for (const key of Object.keys(picks[name])) delete picks[name][key];
    }
    for (const member of members || []) nameByUser.set(member.user_id,member.display_name);
    for (const row of rows || []) {
      const name = nameByUser.get(row.user_id);
      if (name && picks[name]) picks[name][row.game_id] = row.team;
    }
  }
  async function authenticatedLogin() {
    status('Signing in…');
    const selected = app.selectedUser;
    const {data,error} = await db.auth.signInWithPassword({
      email: email.value.trim(), password: document.getElementById('password-input').value
    });
    if (error || !data.user) { status('Unable to sign in. Check your credentials.'); return; }
    try {
      const {data:member,error:memberError} = await db.from('league_members')
        .select('display_name').eq('user_id',data.user.id).single();
      if (memberError || !member || member.display_name !== selected) throw new Error('Account does not match selected player.');
      await loadAuthoritativePicks();
      app.currentUser = selected;
      app.selectedUser = null;
      document.getElementById('login-screen').classList.add('hidden');
      document.getElementById('main-screen').classList.remove('hidden');
      document.getElementById('username').textContent = selected;
      document.getElementById('password-input').value = '';
      app.showMainMenu();
      app.updateMoneyStatus();
      app.updateRecords();
      app.updateStatusMessage();
      app.checkScheduleUpdate();
      app.checkPickReminders();
      addPushButton();
      status('');
    } catch (err) {
      await db.auth.signOut();
      status('Login could not be completed. Verify membership and migrated picks.');
    }
  }
  app.login = authenticatedLogin;
  app.selectUser = function(name) { baseSelectUser(name); email.value = ''; status(''); };
  app.logout = async function() { await db.auth.signOut(); baseLogout(); };

  app.saveWeekPicks = async function() {
    if (!this.currentUser) return;
    const draft = this.getDraft();
    const week = schedule[this.currentWeek];
    if (!week) return;
    const button = document.getElementById('save-picks-btn');
    if (button) button.disabled = true;
    let saved = 0, rejected = 0;
    try {
      for (const game of week.games) {
        const choice = draft[game.id];
        if (!choice || choice === picks[this.currentUser][game.id]) continue;
        const {error} = await db.rpc('submit_league_pick', {
          p_game_id:game.id, p_team:choice
        });
        if (error) { rejected++; continue; }
        picks[this.currentUser][game.id] = choice;
        saved++;
      }
      // Reconcile with authoritative state after submissions.
      await loadAuthoritativePicks();
      if (button) button.textContent = `Saved ${saved} pick(s)`;
      const note = document.getElementById('save-picks-note');
      if (note) note.textContent = rejected ? `${rejected} pick(s) rejected or locked by server.` : 'Picks confirmed by server.';
      this._draftKey = null;
      this.renderGames();
      this.updateMoneyStatus();
      this.updateStatusMessage();
    } catch (_) {
      if (button) button.textContent = 'Save failed. Retry.';
    } finally { if (button) button.disabled = false; }
  };

  function base64UrlToBytes(value) {
    const padding = '='.repeat((4-value.length%4)%4);
    const raw = atob((value+padding).replace(/-/g,'+').replace(/_/g,'/'));
    return Uint8Array.from(raw,c=>c.charCodeAt(0));
  }
  async function enablePush() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
      alert('Push notifications are unavailable in this browser. On iPhone, add the app to your Home Screen first.');
      return;
    }
    if (!cfg.vapidPublicKey) { alert('Push service is not configured yet.'); return; }
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return;
    const registration = await navigator.serviceWorker.register('./push-sw.js', {scope:'./'});
    const sub = await registration.pushManager.subscribe({
      userVisibleOnly:true,applicationServerKey:base64UrlToBytes(cfg.vapidPublicKey)
    });
    const {data:{user}} = await db.auth.getUser();
    if (!user) throw new Error('Sign in first');
    const subscription = sub.toJSON();
    // The endpoint uniquely identifies this browser's subscription.
    await db.from('push_subscriptions').delete().eq('endpoint',sub.endpoint);
    const {error} = await db.from('push_subscriptions').insert({
      endpoint:sub.endpoint,user_id:user.id,subscription
    });
    if (error) throw error;
    alert('Push reminders enabled for this device.');
  }
  function addPushButton() {
    if (document.getElementById('enable-tnf-push')) return;
    const button = document.createElement('button');
    button.id = 'enable-tnf-push';
    button.className = 'btn btn-gold';
    button.textContent = 'Enable TNF Notifications';
    button.style.margin = '10px';
    button.addEventListener('click',()=>enablePush().catch(()=>alert('Could not enable notifications. Please try again.')));
    document.getElementById('main-screen').prepend(button);
  }
  // Require an explicit sign-in for each player selection. Sign out before showing login.\n  const originalSelectUser = app.selectUser;\n  app.selectUser = async function(name) {\n    await db.auth.signOut();\n    originalSelectUser(name);\n  };
}
