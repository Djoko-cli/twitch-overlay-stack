/* =========================================================================
   TwitchLive — données Twitch partagées par tous les widgets.

   Chaque source OBS est un contexte JS séparé : ce fichier est donc chargé
   une fois par widget, et chacun interroge Twitch de son côté. Avec un
   intervalle de 45 s et 4 widgets, on reste très loin des limites de l'API
   (800 requêtes/minute).

   Identifiants : config.js d'abord, localStorage ensuite. config.js est lu
   quelle que soit l'origine de la page, y compris en file:// — c'est le seul
   moyen fiable quand une source OBS n'est pas servie depuis la même origine
   que l'overlay d'alertes.

   Usage :
     TwitchLive.onUpdate(state => { ... });   // appelé immédiatement puis à
     TwitchLive.start();                      // chaque rafraîchissement
   ========================================================================= */
(function (global) {
  const CFG = global.LG_CONFIG || {};

  const LS_CLIENT_ID = 'lg_alerts_client_id';
  const LS_TOKEN = 'lg_alerts_token';
  const LS_LAST_FOLLOW = 'lg_last_follower';
  const LS_LAST_SUB = 'lg_last_sub';

  function stored(key) {
    try { return localStorage.getItem(key); } catch (e) { return null; }
  }
  function store(key, value) {
    try { localStorage.setItem(key, value); } catch (e) {}
  }

  const clientId = CFG.clientId || stored(LS_CLIENT_ID);
  const token = CFG.token || stored(LS_TOKEN);
  const credSource = CFG.token ? 'config.js'
    : (stored(LS_TOKEN) ? 'localStorage' : 'aucun');
  const enabled = !!(clientId && token);

  const state = {
    enabled,
    credSource,
    ready: false,        // true dès que Twitch a répondu au moins une fois
    live: false,
    liveSince: null,     // Date réelle de début de stream, null hors ligne
    viewers: 0,
    game: '',
    title: '',
    displayName: '',
    lastFollower: stored(LS_LAST_FOLLOW),
    lastSub: stored(LS_LAST_SUB),
    error: null
  };

  const listeners = [];
  function emit() {
    listeners.forEach(fn => { try { fn(state); } catch (e) { console.error(e); } });
  }

  async function helix(path) {
    const res = await fetch('https://api.twitch.tv/helix' + path, {
      headers: { 'Client-Id': clientId, 'Authorization': 'Bearer ' + token }
    });
    if (!res.ok) throw new Error(path + ' → ' + res.status);
    return res.json();
  }

  let broadcasterId = null;

  async function refresh() {
    try {
      if (!broadcasterId) {
        const me = await helix('/users');
        const u = me.data && me.data[0];
        if (!u) throw new Error('compte introuvable');
        broadcasterId = u.id;
        state.displayName = u.display_name;
      }

      const streams = await helix('/streams?user_id=' + broadcasterId);
      const live = streams.data && streams.data[0];
      if (live) {
        state.live = true;
        state.liveSince = new Date(live.started_at);
        state.viewers = live.viewer_count;
        if (live.game_name) state.game = live.game_name;
        if (live.title) state.title = live.title;
      } else {
        state.live = false;
        state.liveSince = null;
        state.viewers = 0;
      }

      /* channel info : jeu et titre restent disponibles hors ligne */
      const ch = await helix('/channels?broadcaster_id=' + broadcasterId);
      const info = ch.data && ch.data[0];
      if (info) {
        if (info.game_name) state.game = info.game_name;
        if (info.title) state.title = info.title;
      }

      /* dernier follower — nécessite le scope moderator:read:followers */
      try {
        const f = await helix('/channels/followers?broadcaster_id=' + broadcasterId + '&first=1');
        const latest = f.data && f.data[0];
        if (latest) {
          state.lastFollower = latest.user_name;
          store(LS_LAST_FOLLOW, latest.user_name);
        }
      } catch (e) { /* scope absent — on garde la dernière valeur connue */ }

      /* le dernier sub ne vient que de l'overlay d'alertes (aucun endpoint
         Helix ne donne l'abonné le plus récent) */
      const sub = stored(LS_LAST_SUB);
      if (sub) state.lastSub = sub;

      state.ready = true;
      state.error = null;
    } catch (e) {
      state.error = e.message;
      console.warn('TwitchLive:', e.message);
    }
    emit();
  }

  global.TwitchLive = {
    enabled,
    credSource,
    state,
    stored,
    onUpdate(fn) { listeners.push(fn); fn(state); },
    start(intervalMs) {
      if (!enabled) { emit(); return; }
      refresh();
      setInterval(refresh, intervalMs || 45000);
    },
    /* ms → "HH:MM:SS" */
    formatDuration(ms) {
      const d = Math.max(0, ms);
      const p = n => String(n).padStart(2, '0');
      return p(Math.floor(d / 3600000)) + ':' +
             p(Math.floor((d % 3600000) / 60000)) + ':' +
             p(Math.floor((d % 60000) / 1000));
    }
  };
})(window);
