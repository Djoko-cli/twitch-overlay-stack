/* =========================================================================
   Mise à l'échelle globale — ?scale=

   Toute la stack est dessinée en pixels pour un canvas 1920×1080. Sur un
   canvas 3840×2160, une source OBS deux fois plus grande affiche le même
   contenu en 1× : le widget paraît donc deux fois plus petit par rapport à
   la scène. ?scale=2 corrige ça.

   Chaque page applique ensuite `zoom: var(--scale)` sur son élément visuel
   racine. `zoom` (contrairement à `transform: scale`) agit sur la mise en
   page : les ombres, les rayons et les mesures internes suivent, donc la
   détection de débordement du texte reste juste.

   À charger dans <head>, avant le premier rendu.
   ========================================================================= */
(function () {
  const raw = new URLSearchParams(location.search).get('scale');
  if (!raw) return;
  const s = parseFloat(raw);
  if (!isFinite(s) || s <= 0) return;
  document.documentElement.style.setProperty('--scale', Math.min(6, s));
})();
