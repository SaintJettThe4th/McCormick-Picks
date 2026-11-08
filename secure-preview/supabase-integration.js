// Opt-in cutover: legacy behavior is unchanged until enabled explicitly.
// Activate only AFTER both accounts, fixtures and historical picks are verified.
import { supabaseClient as db } from './supabase-client.js';
const cfg = window.MCCORMICK_SUPABASE_CONFIG;
if (cfg?.enableSupabaseMode === true) {
  if (!db) throw new Error('Supabase mode enabled without a valid public client configuration.');
  const nameByUser = new Map();
  const verifiedKickoffs = new Map();
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

  // The preview has no #money-status panel. Legacy updateMoneyStatus throws
  // when called after a successful login, which previously triggered sign-out.
  const baseUpdateMoneyStatus = app.updateMoneyStatus.bind(app);
  app.updateMoneyStatus = function() {
    if (!document.getElementById('money-status')) return;
    return baseUpdateMoneyStatus();
  };

  const baseLogout = app.logout.bind(app);
  const baseSelectUser = app.selectUser.bind(app);
  const baseCancelLogin = app.cancelLogin.bind(app);

  // Never synthesize historical selections or save them to localStorage in secure mode.
  app.loadPicks = () => {};
  app.autoPickLockedGames = () => {};
  app.savePicks = () => {};
  app.passwords = Object.create(null);
  // Inline script initializes on DOMContentLoaded; modules may execute later.
  // Clear baked-in selections immediately so no hardcoded picks leak into secure mode.
  for (const name of ['Jett','Kevin']) {
    for (const key of Object.keys(picks[name])) delete picks[name][key];
  }
  // The live legacy init may already have run. No localStorage writes are allowed
  // after secure mode is enabled; authoritative picks load only after login.

  async function loadAuthoritativePicks() {
    const [{data:members,error:membersError},{data:rows,error:picksError},{data:games,error:gamesError}] = await Promise.all([
      db.from('league_members').select('user_id,display_name'),
      db.from('league_picks').select('game_id,user_id,team'),
      db.from('league_games').select('id,kickoff_at'),
    ]);
    if (membersError || picksError || gamesError) throw membersError || picksError || gamesError;
    verifiedKickoffs.clear();
    for (const game of games || []) {
      if (game.kickoff_at) verifiedKickoffs.set(game.id,Date.parse(game.kickoff_at));
    }
    for (const name of ['Jett','Kevin']) {
      for (const key of Object.keys(picks[name])) delete picks[name][key];
    }
    for (const member of members || []) nameByUser.set(member.user_id,member.display_name);
    for (const row of rows || []) {
      const name = nameByUser.get(row.user_id);
      if (name && picks[name]) picks[name][row.game_id] = row.team;
    }
  }
  let loginPending = false;
  async function authenticatedLogin() {
    if (loginPending) return;
    loginPending = true;
    status('Signing in…');
    const selected = app.selectedUser;
    if (!selected || !['Jett','Kevin'].includes(selected)) {
      loginPending = false;
      status('Choose Jett or Kevin before signing in.');
      return;
    }
    try {
      const {data,error} = await db.auth.signInWithPassword({
        email: email.value.trim(), password: document.getElementById('password-input').value
      });
      if (error || !data?.user) throw new Error('Sign-in rejected');
      const {data:member,error:memberError} = await db.from('league_members')
        .select('display_name').eq('user_id',data.user.id).single();
      if (memberError || !member || member.display_name !== selected) throw new Error('Account does not match selected player.');
      await loadAuthoritativePicks();
      app._draftKey = null;
      app._draft = {};
      app.currentUser = selected;
      app.selectedUser = null;
      document.getElementById('login-screen').classList.add('hidden');
      document.getElementById('main-screen').classList.remove('hidden');
      document.getElementById('username').textContent = selected;
      document.getElementById('password-input').value = '';
      // Auth is complete. Never undo a valid session because optional UI fails.
      const postLoginSteps = [
        () => app.showMainMenu(),
        () => app.updateMoneyStatus(),
        () => app.updateRecords(),
        () => app.updateStatusMessage(),
        () => app.checkScheduleUpdate(),
        () => app.checkPickReminders(),
        () => addPushButton()
      ];
      for (const step of postLoginSteps) {
        try { step(); } catch (uiError) { console.error('Post-login UI error', uiError); }
      }
      status('');
    } catch (err) {
      console.error('Secure preview login failed', err);
      document.getElementById('main-screen').classList.add('hidden');
      document.getElementById('login-screen').classList.remove('hidden');
      await db.auth.signOut().catch(() => {});
      app.currentUser = null;
      for (const name of ['Jett','Kevin']) {
        for (const key of Object.keys(picks[name])) delete picks[name][key];
      }
      status('Login failed: ' + (err?.message || 'Check credentials and connection.'));
    } finally {
      loginPending = false;
      document.getElementById('password-input').value = '';
    }
  }
  app.login = authenticatedLogin;
  app.selectUser = function(name) { baseSelectUser(name); email.value = ''; status(''); };
  app.cancelLogin = function() { email.value = ''; status(''); baseCancelLogin(); };
  app.logout = async function() {
    app.currentUser = null;
    app._draftKey = null;
    app._draft = {};
    for (const name of ['Jett','Kevin']) {
      for (const key of Object.keys(picks[name])) delete picks[name][key];
    }
    try { await db.auth.signOut(); } finally { email.value = ''; status(''); baseLogout(); }
  };
  // Diagnostic stays on the games screen so users do not need DevTools.
  function displayGameFeedback(message, error = false) {
    let node = document.getElementById('preview-game-feedback');
    if (!node) {
      node = document.createElement('div');
      node.id = 'preview-game-feedback';
      node.setAttribute('role', 'status');
      node.style.cssText = 'padding:12px;margin:10px 0;border-radius:8px;border:1px solid #c9a227;background:#172635;font-size:13px;font-weight:600;text-align:center;';
      document.getElementById('games-list').before(node);
    }
    node.style.color = error ? '#fca5a5' : '#86efac';
    node.textContent = message;
  }
  const baseShowGames = app.showGames.bind(app);
  app.showGames = function() {
    baseShowGames();
    displayGameFeedback(this.currentUser
      ? 'Signed in as ' + this.currentUser + '. Select an unlocked game.'
      : 'NOT SIGNED IN. Return to login and sign in with Supabase.', !this.currentUser);
  };

  // Capture game clicks before legacy inline handlers; keep selection in the secure draft.
  // This does not submit anything to the database until Save Picks is pressed.
  document.getElementById('games-list')?.addEventListener('click', (event) => {
    const button = event.target.closest('button.team-btn[data-team-code]');
    if (!button) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const card = button.closest('.game[data-game-id]');
    const gameId = card?.dataset.gameId;
    const teamCode = button.dataset.teamCode;
    const week = schedule[app.currentWeek];
    const game = week?.games.find(g => g.id === gameId);
    if (!app.currentUser) {
      displayGameFeedback('Selection blocked: no active login session. Sign in again.', true);
      return;
    }
    if (!game || app.isGameLocked(game)) {
      displayGameFeedback('Selection blocked: this game is locked or kickoff has not been verified.', true);
      return;
    }
    app.getDraft()[gameId] = teamCode;
    card.querySelectorAll('button.team-btn').forEach(el => {
      const selected = el.dataset.teamCode === teamCode;
      el.classList.toggle('selected', selected);
      el.setAttribute('aria-pressed', String(selected));
    });
    let label = card.querySelector('.preview-pick-label');
    if (!label) {
      label = document.createElement('div');
      label.className = 'preview-pick-label';
      label.style.cssText = 'text-align:center;margin-top:12px;color:#c9a227;font-weight:600;font-size:13px';
      card.querySelector('.game-content').appendChild(label);
    }
    label.textContent = 'Your pick: ' + (teams[teamCode]?.name || teamCode) + ' (not saved)';
    displayGameFeedback('Selected ' + (teams[teamCode]?.name || teamCode) + ' (not saved).');
  }, true);

  // Fail closed on games without a verified server kickoff. Client display is advisory;
  // submit_league_pick independently enforces the deadline using the server clock.
  app.isGameLocked = function(game) {
    if (!game || game.final) return true;
    const kickoff = verifiedKickoffs.get(game.id);
    return !Number.isFinite(kickoff) || Date.now() >= kickoff;
  };

  // Show a durable status after renderGames rebuilds the save button.
  let lastSaveFeedback = '';
  const showSaveFeedback = (message, error = false) => {
    lastSaveFeedback = message;
    const note = document.getElementById('save-picks-note');
    if (note) {
      note.textContent = message;
      note.style.color = error ? '#fca5a5' : '#86efac';
      note.style.fontWeight = '700';
      note.setAttribute('role', 'status');
      note.setAttribute('aria-live', 'polite');
    }
  };
  app.saveWeekPicks = async function() {
    if (!this.currentUser) { showSaveFeedback('Sign in before saving picks.', true); return; }
    const week = schedule[this.currentWeek];
    if (!week) { showSaveFeedback('No games found for this week.', true); return; }
    const draft = this.getDraft();
    const pending = week.games.filter(game => draft[game.id] && draft[game.id] !== picks[this.currentUser]?.[game.id]);
    if (!pending.length) {
      showSaveFeedback('No new picks to save. Your existing selections are unchanged.');
      return;
    }
    const button = document.getElementById('save-picks-btn');
    if (button) { button.disabled = true; button.textContent = 'Saving…'; }
    let saved = 0;
    const errors = [];
    try {
      for (const game of pending) {
        if (this.isGameLocked(game)) {
          errors.push(game.id + ': game is locked or kickoff is unverified');
          continue;
        }
        const {error} = await db.rpc('submit_league_pick', {
          p_game_id: game.id, p_team: draft[game.id]
        });
        if (error) {
          console.error('Pick submission rejected', game.id, error);
          errors.push(game.id + ': ' + (error.message || 'server rejected pick'));
          continue;
        }
        saved++;
      }
      await loadAuthoritativePicks();
      this._draftKey = null;
      this._draft = {};
      this.renderGames();
      const confirmed = pending.filter(game => picks[this.currentUser]?.[game.id] === draft[game.id]).length;
      const message = errors.length
        ? 'Confirmed ' + confirmed + ' of ' + pending.length + ' picks. ' + errors[0]
        : confirmed === pending.length
          ? 'Confirmed: ' + confirmed + ' pick(s) saved and verified with Supabase.'
          : 'Only ' + confirmed + ' of ' + pending.length + ' picks verified after reload. Please retry.';
      showSaveFeedback(message, errors.length > 0 || confirmed !== pending.length);
      this.updateMoneyStatus();
      this.updateStatusMessage();
    } catch (error) {
      console.error('Save Picks failed', error);
      showSaveFeedback('Save failed: ' + (error?.message || 'Unable to verify picks.'), true);
    } finally {
      const currentButton = document.getElementById('save-picks-btn');
      if (currentButton) { currentButton.disabled = false; currentButton.textContent = 'Save Picks'; }
    }
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
    const {error} = await db.from('push_subscriptions').insert({
      endpoint:sub.endpoint,user_id:user.id,subscription
    });
    // Existing subscription is already registered; never delete another account's endpoint.
    if (error?.code === '23505') {
      alert('This device is already registered. Sign out of the other account before switching notifications.');
      return;
    }
    if (error) throw error;
    alert('Push reminders enabled for this device.');
  }
  function addPushButton() {
    if (document.getElementById('enable-tnf-push')) return;
    const button = document.createElement('button');
    button.id = 'enable-tnf-push';
    button.className = 'btn btn-gold';
    button.textContent = cfg.vapidPublicKey ? 'Enable TNF Notifications' : 'TNF Notifications: Setup Pending';
    button.disabled = !cfg.vapidPublicKey;
    button.style.margin = '10px';
    button.addEventListener('click',()=>enablePush().catch(()=>alert('Could not enable notifications. Please try again.')));
    document.getElementById('main-screen').prepend(button);
  }
  // Preview-only diagnostics: never silently show an empty games list.
  const originalRenderGames = app.renderGames.bind(app);
  app.renderGames = function() {
    const container = document.getElementById('games-list');
    try {
      originalRenderGames();
      if (document.getElementById('games-section') && !document.getElementById('games-section').classList.contains('hidden')) {
        const current = document.getElementById('preview-game-feedback')?.textContent || '';
        if (!current.startsWith('Selected ')) displayGameFeedback(this.currentUser
          ? 'Signed in as ' + this.currentUser + '. Select an unlocked game.'
          : 'NOT SIGNED IN. Return to login and sign in with Supabase.', !this.currentUser);
      }
      if (lastSaveFeedback) showSaveFeedback(lastSaveFeedback, /failed|locked|rejected|Only |Confirmed \\d+ of/.test(lastSaveFeedback));
      const count = schedule[this.currentWeek]?.games?.length ?? 0;
      if (count && !container.querySelector('.game')) {
        container.textContent = 'Preview error: no game cards rendered for this week.';
      }
    } catch (error) {
      console.error('Secure preview games rendering failed', error);
      container.textContent = 'Unable to display games. Error: ' + (error?.message || 'unknown');
    }
  };

  // Player selection does not mutate the existing auth session; login checks identity.
}
