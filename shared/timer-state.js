/* =========================================================================
   TimerState — état partagé du décompte "starting soon", piloté depuis
   controls/timer.html et lu par screens/starting-soon.html.

   Synchronisé via une petite API HTTP locale (server.py, route /api/timer),
   PAS via localStorage. Raison : le panneau de contrôle tourne dans ton
   navigateur normal pendant que la source OBS tourne dans le moteur CEF
   isolé d'OBS — deux moteurs différents ne partagent jamais leur
   localStorage, même sur la même origine. Un vrai aller-retour réseau vers
   ce serveur traverse cette frontière, peu importe qui appelle.

   Le format est inchangé : { targetISO, paused, remainingMs }.
   - targetISO fait foi quand paused=false.
   - remainingMs fait foi quand paused=true (temps gelé au moment de la pause).

   API exposée : identique à avant (load/remainingMs/startDuration/
   startAbsolute/adjust/pause/resume/reset), plus TimerState.ready — une
   Promise qui se résout après la première tentative de lecture serveur.
   Les pages doivent l'attendre avant de décider d'un éventuel repli "aucun
   minuteur encore réglé → 10 min par défaut", sinon ce repli s'exécuterait
   à chaque chargement avant que la vraie valeur serveur n'arrive, écrasant
   l'état à chaque fois. */
(function (global) {
  const API = '/api/timer';
  let cache = null;
  let lastPollOk = false;

  async function pollOnce() {
    try {
      const res = await fetch(API, { cache: 'no-store' });
      lastPollOk = res.ok;
      if (res.ok) {
        const data = await res.json();
        if (data && typeof data.targetISO === 'string') cache = data;
      }
    } catch (e) {
      lastPollOk = false;
      /* réseau/serveur indisponible — on garde le dernier état connu et on
         retentera au prochain sondage plutôt que de planter */
    }
    return cache;
  }

  const ready = pollOnce();
  setInterval(pollOnce, 1000);

  function setLocal(state) { cache = state; return state; }

  async function pushToServer(state) {
    try {
      await fetch(API, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(state)
      });
      lastPollOk = true;
    } catch (e) {
      lastPollOk = false;
      console.warn('TimerState: échec de synchronisation serveur —', e.message);
    }
  }

  function remainingMs(state) {
    if (!state) return 0;
    if (state.paused) return Math.max(0, state.remainingMs);
    return Math.max(0, new Date(state.targetISO).getTime() - Date.now());
  }

  function startDuration(minutes) {
    const s = setLocal({
      targetISO: new Date(Date.now() + minutes * 60000).toISOString(),
      paused: false,
      remainingMs: 0
    });
    pushToServer(s);
    return s;
  }

  function startAbsolute(date) {
    const s = setLocal({ targetISO: date.toISOString(), paused: false, remainingMs: 0 });
    pushToServer(s);
    return s;
  }

  function adjust(deltaMinutes) {
    const base = cache;
    if (!base) return startDuration(Math.max(0, deltaMinutes));

    const deltaMs = deltaMinutes * 60000;
    const next = base.paused
      ? { targetISO: base.targetISO, paused: true, remainingMs: Math.max(0, base.remainingMs + deltaMs) }
      : { targetISO: new Date(Math.max(Date.now(), new Date(base.targetISO).getTime() + deltaMs)).toISOString(), paused: false, remainingMs: 0 };

    setLocal(next);
    pushToServer(next);
    return next;
  }

  function pause() {
    if (!cache || cache.paused) return cache;
    const next = { targetISO: cache.targetISO, paused: true, remainingMs: remainingMs(cache) };
    setLocal(next);
    pushToServer(next);
    return next;
  }

  function resume() {
    if (!cache || !cache.paused) return cache;
    const next = {
      targetISO: new Date(Date.now() + cache.remainingMs).toISOString(),
      paused: false,
      remainingMs: 0
    };
    setLocal(next);
    pushToServer(next);
    return next;
  }

  function reset(minutes) {
    return startDuration(minutes == null ? 10 : minutes);
  }

  function load() { return cache; }

  global.TimerState = {
    ready,
    get lastPollOk() { return lastPollOk; },
    load, remainingMs, startDuration, startAbsolute, adjust, pause, resume, reset
  };
})(window);
