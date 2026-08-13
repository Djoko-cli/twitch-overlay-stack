/* =========================================================================
   Petits utilitaires partagés par les widgets autonomes.

   Doit être chargé APRÈS que <body> existe (script en fin de body), puisque
   l'ancrage écrit directement sur document.body.
   ========================================================================= */
(function (global) {
  const params = new URLSearchParams(location.search);

  /* ?anchor=center | top-left | top | top-right | left | right |
             bottom-left | bottom | bottom-right
     body est une flexbox en ligne : justify-content pilote l'horizontale et
     align-items la verticale. Une valeur inconnue retombe sur center. */
  function applyAnchor() {
    const parts = (params.get('anchor') || 'center').toLowerCase().trim().split(/[-_ ]+/);
    const V = { top: 'flex-start', bottom: 'flex-end', center: 'center' };
    const H = { left: 'flex-start', right: 'flex-end', center: 'center' };
    let v = 'center', h = 'center';
    parts.forEach(p => {
      if (V[p] && p !== 'center') v = V[p];
      if (H[p] && p !== 'center') h = H[p];
    });
    document.body.style.alignItems = v;
    document.body.style.justifyContent = h;
  }

  const debugEl = document.getElementById('debug');
  const DEBUG = params.get('debug') === '1';
  if (DEBUG && debugEl) debugEl.style.display = 'block';

  const bits = {};
  function setDebug(key, value) {
    if (!debugEl) return;
    bits[key] = value;
    debugEl.textContent = Object.entries(bits).map(([k, v]) => k + ': ' + v).join('  ·  ');
  }

  /* ?solid=1 : fond quasi-opaque au lieu du fond translucide habituel — voir
     .glass-solid dans shared/liquid-glass.css pour le pourquoi (une page ne
     peut pas flouter ce qu'OBS compose derrière elle, donc la seule garantie
     de lisibilité par-dessus n'importe quel fond est un fill couvrant).
     Ajoute .glass-solid à tout élément .glass déjà présent dans le DOM
     (couvre nameplate/uptime/latest, dont la pastille est statique) et pose
     .solid sur <body> pour les pages qui construisent leur carte plus tard
     ou n'utilisent pas la classe .glass directement (frame.html, music). */
  const SOLID = params.get('solid') === '1';
  if (SOLID) {
    document.body.classList.add('solid');
    document.querySelectorAll('.glass').forEach(el => el.classList.add('glass-solid'));
  }

  applyAnchor();

  global.Widget = { params, DEBUG, SOLID, setDebug };
})(window);
