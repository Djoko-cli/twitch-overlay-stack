# Stack UI Twitch — Liquid Glass

Une stack complète d'overlays pour OBS, chaîne cible : **djokoow**.
Aucune installation requise pour le chat / cadre webcam / écrans : ce sont des
fichiers HTML statiques que tu ajoutes directement dans OBS comme "Browser
Source" (fichier local). Les **alertes** demandent un peu plus de config
(voir plus bas) car elles nécessitent une connexion OAuth à Twitch.

```
Twitch/
├── server.py                   ⭐ lance ça, pas `python3 -m http.server`
├── config.js                   ⚠️ identifiants Twitch — voir ci-dessous
├── diag.html                   page de diagnostic (à ouvrir en cas de souci)
├── shared/liquid-glass.css     styles communs (ne pas ajouter dans OBS)
├── chat/index.html             overlay de chat en direct
├── alerts/index.html           alertes follow / sub / gift / raid / cheer
├── music/index.html            "en écoute" Spotify (pochette + progression)
├── widgets/                    ⭐ briques indépendantes, une source OBS chacune
│   ├── frame.html              cadre glass seul (+ réaction micro)
│   ├── nameplate.html          pseudo + jeu en cours
│   ├── uptime.html             EN DIRECT + chrono (+ viewers, + heure)
│   └── latest.html             dernier follower / dernier sub
├── webcam-frame/index.html     ancienne version tout-en-un (voir plus bas)
├── controls/timer.html         panneau (pour toi, pas OBS) : pilote le compte à rebours
└── screens/
    ├── starting-soon.html      écran "le stream démarre bientôt"
    ├── brb.html                écran de pause
    ├── ending.html              écran de fin de stream
    └── stinger.html             transition animée entre scènes
```

## Lancer le serveur

```bash
python3 server.py 5500
```

C'est un remplaçant direct de `python3 -m http.server 5500` (mêmes fichiers
servis, même port par défaut) — utilise **celui-ci**, pas l'autre. Il ajoute
un point d'API (`/api/timer`) dont a besoin `controls/timer.html` pour
synchroniser le compte à rebours avec la source OBS (voir section 6) : sans
lui, le panneau de contrôle et la source ne peuvent pas communiquer, même
servis à la même adresse. Si tu lances l'ancien `http.server` par erreur, le
panneau te le signale avec un bandeau d'avertissement plutôt que d'échouer
en silence.

## `config.js` — identifiants sans passer par l'interface

Toutes les pages chargent `config.js`. C'est le moyen le plus simple de leur
donner les identifiants Twitch, et surtout **le seul qui fonctionne quelle que
soit l'origine de la source** : le `localStorage` (rempli quand tu cliques sur
"Se connecter avec Twitch") est isolé par origine, donc une source ajoutée en
`file://` ou sur un autre port ne le voit jamais. C'est la cause classique du
cadre webcam qui ne se synchronise pas avec Twitch.

```js
window.LG_CONFIG = {
  clientId: '...',   // PUBLIC — aucun risque
  token: '',         // SECRET — voir l'avertissement
  channel: 'djokoow'
};
```

- **`clientId`** est public par conception (il est fait pour être visible dans
  du code client). Le laisser en dur ne pose aucun problème.
- **`token`** est un secret : il donne accès en lecture à tes followers, subs
  et bits au nom de ton compte. Ne le mets pas en screen-share, ne le commite
  pas (un `.gitignore` exclut déjà `config.js`), et sache qu'il **expire au
  bout de ~60 jours**.
- Si `token` reste vide, tout retombe sur le fonctionnement normal avec le
  bouton de connexion — rien ne casse.

**Pour récupérer ton token sans outil externe** : ouvre `diag.html` depuis la
même origine que l'overlay d'alertes (celle où tu t'es connecté). Le token y
est affiché avec un bouton "Copier" ; colle-le dans `config.js`.

**Si un token a été exposé** (partagé, screen-shared, collé dans une
conversation), reconnecte-toi via l'overlay d'alertes : ça en génère un
nouveau et invalide l'ancien.

## `diag.html` — quand quelque chose ne marche pas

Ouvre cette page **exactement comme tu ouvres tes sources dans OBS** (clic
droit sur une source → Interagir, ou la même URL dans un navigateur).

**Section Twitch** — protocole utilisé, chargement de `config.js`, présence
d'un token visible depuis cette origine (affiché masqué, avec un bouton
Copier), validité du token, état en ligne / hors ligne avec la durée réelle du
live, et permissions accordées.

**Section Spotify** — présence du Client ID, détection du Client Secret collé
par erreur à la place du refresh token, **validation réelle** du refresh token
(la page demande un token d'accès à Spotify pour vérifier qu'il marche
vraiment), et affichage du morceau en cours.

C'est aussi le moyen le plus simple d'**obtenir le refresh token Spotify** :
la page peut lancer l'autorisation elle-même. Ajoute
`http://127.0.0.1:5500/diag.html` comme Redirect URI dans ton app Spotify,
clique sur *Se connecter à Spotify*, et le token s'affiche au retour avec un
bouton Copier — prêt à coller dans `config.js`.

Chaque problème détecté vient avec sa correction.

## Canvas 4K — `?scale=2`

Toute la stack est dessinée en pixels pour un canvas **1920×1080**. Sur un
canvas **3840×2160**, une source deux fois plus grande affiche le même
contenu en 1× : le widget paraît donc deux fois plus petit par rapport à la
scène.

**Ajoute `?scale=2` à l'URL de chaque source**, et double les tailles de
source conseillées :

```
http://127.0.0.1:5500/widgets/uptime.html?scale=2
http://127.0.0.1:5500/music/index.html?layout=compact&scale=2
http://127.0.0.1:5500/chat/index.html?scale=2
http://127.0.0.1:5500/screens/starting-soon.html?scale=2
```

`?scale=` accepte n'importe quelle valeur entre 0 et 6 (`1.5` pour du 1440p,
par exemple). Toutes les pages le gèrent, y compris les marges du halo — qui
grossissent aussi, sinon la réserve redeviendrait insuffisante et le halo
serait de nouveau tranché.

> Détail technique : la mise à l'échelle utilise `zoom` et non
> `transform: scale`. `zoom` agit sur la mise en page, donc les mesures
> internes restent justes — la détection de débordement du texte du widget
> musique continue de fonctionner correctement à toute échelle. Le chat et le
> cadre webcam, dont les dimensions dépendent de `100%` / `100vh`,
> multiplient leurs tailles explicitement plutôt que d'utiliser `zoom`, qui
> les ferait déborder de leur source.

## Important à savoir sur le "blur"

`backdrop-filter` (le flou du verre) ne peut flouter que ce qui est **dans la
page HTML elle-même**. OBS compose le Browser Source par-dessus ta scène
*après* que la page a été rendue, donc l'overlay ne peut pas réellement
flouter ton jeu ou ta webcam en dessous — c'est une limite technique d'OBS,
pas de ce projet. Le rendu "glass" vient de couches de transparence, de
dégradés et de bordures lumineuses, qui donnent un résultat très proche visuellement.
Les écrans plein écran (starting-soon / brb / ending), eux, floutent
vraiment leurs propres formes de couleur animées en fond.

Si tu veux un vrai flou de ton jeu/webcam derrière le chat, tu peux ajouter le
plugin OBS gratuit **"Blur" par Exeldro** en filtre sur ta source de jeu — ce
n'est pas nécessaire, mais ça complète bien l'effet.

### `?solid=1` — rester lisible peu importe ce qu'il y a en dessous

Conséquence directe de la limite ci-dessus : le fond translucide habituel
laisse deviner (voire dominer) ce qu'il y a derrière dans OBS. Sur un fond
sombre ça passe bien ; sur une webcam claire, un jeu qui flashe, ou un chat
qui défile en fond, le texte peut devenir difficile à lire.

Ajoute `?solid=1` à l'URL de n'importe quel widget (`widgets/*.html`,
`music/index.html`) pour remplacer ce fond translucide par un fond sombre
quasi opaque (`.glass-solid` dans `shared/liquid-glass.css`). Toujours
reconnaissable comme "glass" (même reflet, même bordure, même frange
chromatique) mais garanti lisible quel que soit ce qu'il y a dessous — testé
contre un fond blanc/jaune à rayures, le cas le plus défavorable possible.

```
http://127.0.0.1:5500/widgets/uptime.html?solid=1
http://127.0.0.1:5500/music/index.html?layout=compact&solid=1
```

Combinable avec les autres paramètres de chaque widget (`&scale=2`,
`&anchor=`, etc.). Par défaut (sans `?solid=1`), rien ne change.

## 1. Chat overlay (`chat/index.html`)

Fonctionne immédiatement, en lecture seule et anonyme (aucune connexion
requise) via la chaîne `djokoow`. Gère les emotes Twitch et les vrais badges
(sub, mod, VIP…) automatiquement.

**Dans OBS** : Ajouter une source → Navigateur (Browser) → cocher "Fichier
local" → sélectionner `chat/index.html`. Largeur/hauteur conseillées :
480 × 800 (ou toute la hauteur de ta scène), coin bas-gauche.

Paramètres disponibles en modifiant l'URL du fichier (ajoute `?...` à la fin,
possible même en fichier local, ex. `chat/index.html?fontsize=20`) :

| Paramètre  | Défaut    | Effet                                             |
|------------|-----------|----------------------------------------------------|
| `channel`  | djokoow   | chaîne Twitch à suivre                             |
| `limit`    | 8         | nombre max de messages affichés                   |
| `fontsize` | 17        | taille du texte en px                              |
| `fade`     | 0         | secondes avant disparition d'un message (0 = jamais, juste retiré au-delà de `limit`) |
| `debug`    | —         | `1` affiche un badge de statut de connexion         |

## 2. Alertes (`alerts/index.html`)

Utilise **EventSub** (le système actuel de Twitch, pas l'ancien PubSub) pour
follow / sub / sub cadeau / resub / raid / cheer, avec une jolie carte glass
animée et un petit son.

Ceci nécessite un token OAuth, et Twitch **n'accepte pas** les URL `file://`
comme redirection OAuth — il faut donc servir le dossier via http(s).

⚠️ **Utilise `python3 server.py`, pas `npx serve`** : `serve` réécrit
automatiquement `/alerts/index.html` en `/alerts` (et supprime au passage tout
ce qui suit un `?`). Cette URL "nettoyée" ne correspondra plus à celle que tu
as enregistrée dans la console Twitch, et l'autorisation échoue silencieusement
(tu es redirigé après connexion mais la page ne peut rien faire du résultat).
`server.py` sert les fichiers tels quels, sans ce problème.

```bash
cd /Users/Majid/Desktop/Twitch
python3 server.py 5500
```

Puis :
1. Va sur [dev.twitch.tv/console/apps](https://dev.twitch.tv/console/apps) →
   "Register Your Application".
2. Catégorie : "Chat Bot" ou "Website Integration", peu importe.
3. **OAuth Redirect URLs** : ajoute exactement
   `http://localhost:5500/alerts/index.html`
4. Crée l'app, copie le **Client ID**.
5. (Optionnel mais conseillé) Ouvre d'abord `http://localhost:5500/alerts/index.html`
   dans ton navigateur normal pour vérifier que tout est bien configuré — plus
   facile à déboguer là qu'à l'intérieur d'OBS. La page affiche l'URL de
   redirection qu'elle utilise réellement — vérifie qu'elle correspond
   **exactement, caractère pour caractère**, à ce que tu as collé dans la
   console Twitch à l'étape 3 (c'est la cause la plus fréquente d'un login qui
   ne fait "rien"). Entre ton Client ID et connecte-toi ; le statut doit passer
   à "en écoute ✓".
6. Dans OBS, ajoute une source Navigateur pointant vers cette même URL
   `http://localhost:5500/alerts/index.html` (URL, pas "fichier local" cette
   fois). Taille conseillée : 800 × 220, en haut de l'écran.
7. ⚠️ **Étape indispensable** : le navigateur intégré d'OBS a son propre
   stockage, complètement séparé de ton navigateur normal — se connecter à
   l'étape 5 ne suffit pas, il faut refaire la connexion *depuis OBS*. Fais un
   clic droit sur la source → **Interagir** (Interact), une fenêtre s'ouvre où
   tu peux cliquer/taper dans le navigateur d'OBS. Entre le Client ID, clique
   "Se connecter avec Twitch", autorise, et vérifie que le statut passe à
   "en écoute ✓" dans cette fenêtre. Tu peux ensuite la fermer, la source
   continue de tourner.

Le petit badge de statut ("alertes: en écoute ✓") en bas à gauche n'est là que
pour le débogage — il est **caché par défaut**. Ajoute `?debug=1` à la fin de
l'URL uniquement le temps de vérifier la connexion (dans l'étape 5 ou 7
ci-dessus), puis repasse à l'URL sans `?debug=1` dans les propriétés de la
source OBS pour l'usage réel en stream.

**Si ça ne marche toujours pas** : ouvre la page dans un navigateur normal
(pas dans OBS), ouvre les outils de développement (F12) → onglet Console, et
regarde le message d'erreur affiché sur la carte de configuration ou dans la
console — la page affiche maintenant le détail exact de l'échec (scope
manquant, redirect_uri incorrect, token expiré, etc.) au lieu de rester
silencieuse.

Le serveur local doit tourner à chaque session de stream (relance la commande
`python3 server.py 5500` avant d'ouvrir OBS). Le token est réutilisé
automatiquement tant que le navigateur/cache d'OBS garde le `localStorage`.

## 3. Widgets webcam (`widgets/*.html`) — une source OBS par brique

Le cadre webcam était au départ un bloc unique : cadre, plaque, barre de
durée et pastille follower dans la même source, donc impossible à
repositionner séparément. Il est maintenant **découpé en quatre widgets
indépendants**, chacun à placer où tu veux dans ta scène.

| Widget | Contenu | Taille OBS conseillée |
|---|---|---|
| `widgets/frame.html` | l'anneau de verre seul, centre transparent, éclat animé, réaction micro | à la taille exacte de ta webcam |
| `widgets/nameplate.html` | point live + pseudo + jeu en cours | 320 × 80 |
| `widgets/uptime.html` | `EN DIRECT` + chrono, option viewers et heure | 320 × 80 |
| `widgets/latest.html` | dernier follower / dernier sub, en alternance | 320 × 80 |

Les trois pastilles font toutes **38 px de haut** et partagent les mêmes
métriques (padding 9 px, texte 13 px), donc elles s'alignent naturellement
entre elles et avec la version compacte du widget musique.

Chacune se **centre dans sa source** et réserve la place de son halo ; toutes
acceptent `?anchor=` (mêmes neuf positions que le widget musique) et
`?debug=1`.

### Paramètres par widget

**`frame.html`** — `?thickness=16` (épaisseur du cadre), `?mic=0` (couper la
réaction micro), `?micgain=1` (sensibilité).

### `?corners=` — deux formes de cadre

| Valeur | Rendu | Liseré animé |
|---|---|---|
| `round` (défaut) | rayon unique, partagé entre l'intérieur et l'extérieur — la forme d'origine | trace le contour **extérieur** du cadre |
| `plug` | coins **extérieurs droits**, coins **intérieurs** (le trou où la webcam apparaît) arrondis avec `--radius-xl` | trace le contour **intérieur** (le tour du trou) |

```
http://127.0.0.1:5500/widgets/frame.html?corners=plug
```

Le mode `plug` est calculé via un `clip-path` combinant deux tracés SVG
(rectangle net + rectangle arrondi, en trou grâce à la règle `evenodd`)
plutôt que la technique `border-radius` + masque utilisée en mode `round` —
cette dernière ne peut donner qu'un seul rayon, partagé entre l'intérieur et
l'extérieur, donc impossible de désolidariser les deux. Recalculé
automatiquement si la source change de taille.

Combinable avec `?solid=1` et `&scale=`.

**`nameplate.html`** — `?name=` et `?game=` pour forcer les valeurs, sinon
elles viennent de Twitch. `?title=1` affiche le titre du stream à la place du
jeu.

**`uptime.html`** — `?viewers=1` ajoute le nombre de spectateurs, `?clock=1`
ajoute l'heure locale, `?start=` force l'heure de début.

**`latest.html`** — `?show=both|follow|sub`, `?rotate=7` (secondes entre deux
alternances). Le widget **se masque tout seul** tant qu'il n'y a rien à
afficher.

⚠️ **Ajoute ces sources en URL, pas en "fichier local"** :
`http://127.0.0.1:5500/widgets/uptime.html` etc.

> L'ancien `webcam-frame/index.html` (tout-en-un) est conservé et fonctionne
> toujours, si tu préfères une seule source. Les nouveaux widgets partagent
> la même logique via `shared/twitch-live.js`, donc les deux approches
> affichent exactement les mêmes données.

Contenu :
- **plaque bas-centre** : ton pseudo + le jeu en cours,
- **barre bas-gauche** : "EN DIRECT", chrono de stream, nombre de viewers, heure,
- **pastille haut-centre** : alterne entre dernier follower et dernier sub,
- **éclat animé** qui glisse le long de l'arête (même effet que les écrans de
  transition),
- **lueur intérieure réactive au micro** quand tu parles (voir plus bas).

### Données Twitch en direct

Tous ces widgets partagent `shared/twitch-live.js`, qui lit les identifiants
depuis `config.js` (puis, à défaut, le `localStorage`). Ils récupèrent
automatiquement ton pseudo, le jeu, le nombre de viewers, l'heure réelle de
début de stream et le dernier follower.

Chaque source OBS est un contexte JS séparé : chacune interroge donc Twitch
de son côté, toutes les 45 s. Avec quatre widgets on reste très loin des
limites de l'API (800 requêtes/minute).

Sans identifiants, rien ne casse : les widgets retombent sur les valeurs des
paramètres d'URL.

#### Chrono de live

Le chrono est calé sur le `started_at` réel renvoyé par Twitch, pas sur un
compteur qui démarre au chargement : il est recalculé à chaque seconde depuis
cette date absolue, donc il affiche la vraie durée du live même si tu
redémarres OBS ou rafraîchis la source en plein stream, et il ne dérive jamais.

Trois états possibles :

| Situation | Affichage |
|---|---|
| Twitch répond "en live" | `EN DIRECT` + durée réelle, point rouge clignotant |
| Twitch répond "hors ligne" | `HORS LIGNE` + `--:--:--`, point gris — pas de faux compteur |
| Pas de token / pas encore de réponse | `EN DIRECT` + décompte depuis le chargement (approximation) |

Le troisième cas est le repli quand la source est en `file://` : c'est
exactement le comportement "incrémentation bête". Si tu vois ça, c'est que la
source n'est pas servie depuis la même origine que les alertes. Ajoute
`?debug=1` à l'URL pour confirmer — le badge en haut à gauche indique
`twitch: pas de token (voir alerts)`.

Tu peux toujours forcer une heure de début manuelle avec `?start=` : elle
prend le pas sur tout le reste.

Le *dernier sub* ne peut pas être récupéré via l'API (Twitch n'expose aucun
endpoint "abonné le plus récent"), il est donc écrit par l'overlay d'alertes
au moment où un sub arrive. Il apparaît après le premier sub de la session.

### Réaction au micro

OBS **bloque l'accès micro des sources navigateur par défaut**. Pour
l'autoriser, il faut lancer OBS une fois avec un flag spécial :

```bash
/Applications/OBS.app/Contents/MacOS/OBS --use-fake-ui-for-media-stream
```

Il faut aussi qu'OBS ait la permission micro de macOS (Réglages Système →
Confidentialité et sécurité → Microphone → OBS).

Je n'ai pas pu vérifier ce point depuis ici (l'accès micro est bloqué dans mon
environnement de test) — la logique est en place et se dégrade proprement,
mais c'est la partie la plus fragile de la stack. Si ça ne marche pas, ajoute
`?mic=0` pour couper proprement la fonctionnalité, tout le reste continue de
fonctionner normalement.

| Paramètre    | Défaut              | Effet                                     |
|--------------|---------------------|--------------------------------------------|
| `name`       | auto (Twitch)       | force le pseudo affiché sur la plaque      |
| `game`       | auto (Twitch)       | force le texte du jeu                       |
| `thickness`  | 16                  | épaisseur du cadre en px                    |
| `start`      | auto (début réel)   | force l'heure ISO de début pour le chrono   |
| `live`       | activé              | `0` désactive toute requête vers l'API Twitch |
| `mic`        | activé              | `0` désactive la réaction au micro          |
| `micgain`    | 1                   | sensibilité du micro (`0.5` moins, `2` plus) |
| `debug`      | —                   | `1` affiche l'état des connexions en haut à gauche |

## 4. Musique — "en écoute" Spotify (`music/index.html`)

Pochette, titre, artiste, égaliseur animé quand ça joue, et progression. La
lueur prend automatiquement la couleur dominante de la pochette. Les titres
trop longs défilent, les autres non. Le widget disparaît tout seul quand rien
ne joue.

### Deux orientations — `?layout=`

| Valeur | Rendu | Taille OBS **minimale** |
|---|---|---|
| `?layout=full` (défaut) | Grande carte : pochette 62 px, titre et artiste sur deux lignes, barre de progression fine en bas | **490 × 175** |
| `?layout=compact` | Pastille sur une seule ligne : petite pochette ronde, « Titre · Artiste », progression en remplissage de fond | **450 × 85** |

La version compacte fait **36,9 px de haut**, calée sur les pastilles du cadre
webcam (« djokoow · Just Chatting » et la barre « EN DIRECT ») qui font 36 px —
moins d'un pixel d'écart, elles s'alignent donc parfaitement sur la même
ligne de base.

En compact la largeur s'adapte au texte au lieu d'être fixe, et se plafonne à
`?width=` (400 px par défaut) : au-delà, le texte défile.

### Pourquoi la source doit être plus grande que le widget

Les ombres et la lueur colorée sont dessinées **en dehors** de la carte. Si la
source OBS est trop juste, le halo est tranché net au bord — d'où une coupure
franche très visible. Une ombre `0 Ypx Bpx` s'étend de `B−Y` vers le haut,
`B+Y` vers le bas et `B` sur les côtés :

| Variante | Portée réelle du halo (h / b / côtés) | Marge réservée |
|---|---|---|
| `full` | 32 / 48 / 40 px | 34 / 50 / 42 px |
| `compact` | 14 / 22 / 18 px | 18 / 26 / 24 px |

La version compacte a volontairement un halo plus resserré : elle est faite
pour être discrète, et ça permet une source proche de sa taille réelle.

Les tailles du tableau plus haut sont des **minimums**. Plus grand ne coûte
rien (le reste est transparent), plus petit recoupe le halo.

### Ancrage dans la source — `?anchor=`

Le widget est **centré dans sa source par défaut**, pour que la marge du halo
soit répartie sur les quatre côtés. Auparavant il était collé en haut à
gauche, ce qui rognait le halo de ces deux côtés dès que la source était un
peu juste.

Neuf positions acceptées : `center` (défaut), `top-left`, `top`, `top-right`,
`left`, `right`, `bottom-left`, `bottom`, `bottom-right`. Une valeur inconnue
retombe sur `center`.

En pratique tu peux laisser le centrage et **positionner la source elle-même**
dans OBS : c'est plus tolérant, puisqu'agrandir la source ne décale plus le
widget. Les autres ancrages servent si tu veux caler le widget contre un bord
précis d'une zone.

### ⚠️ Spotify impose `127.0.0.1`, pas `localhost`

C'est le piège principal. Spotify **refuse** les Redirect URI en `localhost`
et exige l'adresse de bouclage `127.0.0.1`. Or `localhost` et `127.0.0.1`
sont deux **origines différentes** pour le navigateur : le `localStorage` de
l'une n'est pas visible depuis l'autre.

Le plus simple est donc de **tout servir depuis `127.0.0.1`** :

- ouvre toutes tes sources OBS en `http://127.0.0.1:5500/...`,
- et ajoute `http://127.0.0.1:5500/alerts/index.html` comme Redirect URI
  supplémentaire dans ton app Twitch (elle en accepte plusieurs — garde
  l'ancienne, ça ne casse rien).

Si tu préfères ne rien changer côté Twitch : connecte Spotify une seule fois
depuis `127.0.0.1`, colle le refresh token dans `config.js`, et tout
fonctionnera ensuite depuis n'importe quelle origine — puisque `config.js`
est lu partout.

### Mise en place

1. Crée une app sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard),
   coche l'API **Web API**.
2. Ajoute comme Redirect URI : `http://127.0.0.1:5500/music/index.html`
3. Copie le **Client ID**, colle-le dans `config.js` (`spotifyClientId`) — ou
   directement dans l'écran de connexion de l'overlay.
4. Ouvre `http://127.0.0.1:5500/music/index.html`, clique sur **Se connecter
   à Spotify**, autorise.
5. L'écran affiche alors un **refresh token** (masqué, avec un bouton
   Copier) : colle-le dans `config.js` (`spotifyRefreshToken`).

### Pourquoi un refresh token

Les tokens d'accès Spotify **expirent au bout d'une heure**. Un flux implicite
laisserait l'overlay mourir en plein live sans moyen de se renouveler.
L'overlay utilise donc le flux **Authorization Code + PKCE**, qui fournit un
refresh token — celui-ci n'expire pas, et l'overlay s'en sert pour regénérer
un token d'accès automatiquement une minute avant chaque expiration. C'est ce
qui lui permet de tenir un live de 8 h et de survivre à un redémarrage d'OBS.

PKCE ne nécessite **aucun client secret**, donc rien de sensible côté serveur :
tout tient dans la page.

| Paramètre  | Défaut | Effet                                          |
|------------|--------|--------------------------------------------------|
| `layout`   | full   | `compact` pour la version sur une ligne          |
| `anchor`   | center | position dans la source (voir ci-dessus)         |
| `width`    | 400    | largeur max du widget en px                      |
| `poll`     | 4      | intervalle d'interrogation en secondes (min. 2)  |
| `hideidle` | 1      | `0` garde le widget visible quand rien ne joue   |
| `debug`    | —      | `1` affiche un badge d'état en bas à gauche      |

## 5. Écrans de transition (`screens/*.html`)

Plein écran (1920×1080 conseillé), à activer en changeant de scène dans OBS.

- **starting-soon.html** — `?title=`, `?sub=`. Le compte à rebours se pilote
  normalement depuis `controls/timer.html` (voir juste en dessous) ;
  `?to=2026-08-09T20:00:00` (heure ISO) ou `?minutes=10` restent disponibles
  pour un réglage ponctuel sans passer par le panneau.
- **brb.html** — `?title=`, `?sub=`.
- **ending.html** — `?title=`, `?sub=`, plus `?twitter=`, `?discord=`,
  `?youtube=`, `?tiktok=`, `?instagram=` (chaque paramètre présent ajoute un
  chip avec le pseudo/lien donné).

## 6. Contrôle du minuteur (`controls/timer.html`)

Panneau à ouvrir dans un navigateur normal (**pas** une source OBS — c'est un
outil pour toi, jamais montré aux viewers) pour piloter le compte à rebours
de `starting-soon.html` avec de la vraie flexibilité :

- **Durée** — démarrer un décompte de N minutes depuis maintenant.
- **Heure précise** — viser une date/heure exacte plutôt qu'une durée
  relative.
- **Ajustements rapides** — `−5 / −1 / +1 / +5 min` pendant que le décompte
  tourne, pour un début qui glisse sans tout reconfigurer.
- **Pause / Reprendre** — gèle le temps restant (utile pour un pépin
  technique) sans que le décompte continue à courir dans le vide ; à la
  reprise, il repart du temps qui restait, pas de l'heure figée.
- **Réinitialiser (10 min)** — l'ancien comportement par défaut, maintenant
  un geste volontaire plutôt qu'automatique.

Avant, chaque rechargement de la source `starting-soon.html` dans OBS
relançait bêtement un décompte de 10 minutes depuis l'instant du
rechargement, sans mémoire de la cible réelle.

### Pourquoi ce n'est PAS un pont `localStorage` comme les autres

Les autres ponts inter-pages du projet (Twitch, Spotify, dernier follower/sub)
passent par `localStorage`, et ça marche parce que les deux pages tournent
dans **le même moteur de navigateur** — toutes ajoutées comme sources dans
OBS, donc toutes dans le CEF (Chromium embarqué) d'OBS.

Le panneau de minuteur est différent par nature : il est fait pour tourner
dans **ton navigateur normal**, sur un deuxième écran, pendant qu'OBS affiche
la source dans son propre moteur. Ce sont deux moteurs distincts, chacun avec
son `localStorage` isolé sur disque — même en visant exactement la même URL,
ils ne partagent jamais rien. C'est pour ça qu'un premier essai avec
`localStorage` faisait bien disparaître le "reset bête au rechargement" (la
source OBS relisait son propre stockage, cohérent avec elle-même) mais ne
synchronisait jamais ce qui se passait dans le panneau de contrôle.

La cible vit donc dans un **vrai fichier côté serveur** (`.timer-state.json`,
exclu du dépôt), via le point d'API `/api/timer` de `server.py`. Le panneau
et la source font chacun un aller-retour réseau vers ce serveur — ça
fonctionne quel que soit le navigateur qui appelle, exactement le pont dont
on a besoin ici. La source sonde ce point d'API chaque seconde, donc un
ajustement fait dans le panneau — durée, pause, réglage rapide — apparaît sur
la source **en moins de deux secondes**, sans avoir besoin de l'actualiser.

⚠️ Ça ne fonctionne qu'avec `server.py` (voir en tête de README) — l'ancien
`python3 -m http.server` ne connaît pas la route `/api/timer` et y répond
404. Le panneau détecte ce cas et affiche un bandeau d'avertissement au lieu
d'échouer en silence. Comme pour le reste de la stack : sers les deux pages
depuis **la même origine** (`http://127.0.0.1:5500`), pas en `file://`.

## 7. Transition entre scènes (`screens/stinger.html`)

Un panneau de verre nacré balaie l'écran en diagonale, avec un bord lumineux
à frange chromatique (même motif que le reste de la stack) en tête de
balayage. Au milieu de l'animation, le panneau couvre **tout** le canvas —
c'est l'instant où OBS doit basculer de scène, pendant que rien n'est visible
en dessous.

| Paramètre | Défaut | Effet |
|---|---|---|
| `duration` | 900 | durée totale en ms (400–3000) |
| `direction` | ltr | `rtl` pour balayer droite→gauche |
| `alpha` | — | `1` pour un fond transparent (voir plus bas) |
| `debug` | — | `1` affiche la durée et le point de bascule conseillé |

**Rejouer l'aperçu** : clique n'importe où sur la page, ou appuie sur
Espace / R.

### Fond opaque par défaut — aucune configuration spéciale requise

Le panneau couvrant déjà tout l'écran au point de bascule, la page utilise un
fond sombre opaque (`#0b0713`, comme les écrans de transition) plutôt que
transparent. Résultat : **n'importe quel enregistrement OBS classique**
(MP4, MOV, n'importe quel encodeur) donne un stinger directement utilisable —
zéro réglage d'encodeur, zéro canal alpha à gérer.

### Mise en place (méthode recommandée)

1. Crée une scène temporaire ne contenant **que** cette source Navigateur
   (`http://127.0.0.1:5500/screens/stinger.html?duration=900`), à la taille
   de ton canvas.
2. Lance un enregistrement OBS classique (Paramètres → Sortie, n'importe quel
   format).
3. Clic droit sur la source → **Actualiser** pour relancer l'animation depuis
   le début pendant que l'enregistrement tourne, laisse-la aller jusqu'au
   bout, puis arrête l'enregistrement.
4. `Transitions` (en bas du panneau principal) → **+** → *Stinger* → choisis
   le fichier obtenu.
5. Règle **Transition Point** sur `duration / 2` en ms — le badge `?debug=1`
   te donne la valeur exacte (450 ms pour la durée par défaut de 900 ms).

### Variante avancée — canal alpha via DaVinci Resolve (recommandé)

Si tu veux que le balayage laisse transparaître ton jeu/webcam autour du
panneau au lieu d'un fond uni, la manière la plus fiable n'est **pas**
d'essayer d'enregistrer l'alpha directement dans OBS (ça dépend de plusieurs
réglages qui doivent tous être corrects en même temps, et ça échoue
silencieusement si un seul cloche). Passe par une incrustation dans Resolve
à la place : le fond de la page est une **couleur unie, sans texture ni
bruit** (`#0b0713`), donc l'extraction y est quasi parfaite — bien plus
simple qu'un vrai fond vert filmé.

> ⚠️ Je n'ai pas de licence Resolve à disposition pour vérifier le libellé
> exact des menus sur ta version (Free vs Studio). La logique ci-dessous
> (qualifier une couleur unie, exporter avec alpha) est stable depuis des
> années dans Resolve ; seuls les noms de boutons peuvent varier légèrement.

**1. Enregistrer dans OBS — fond opaque, aucun alpha à gérer**
Utilise le stinger **sans** `?alpha=1` (fond `#0b0713` uni). Enregistre en
`Réglages → Sortie → Mode Avancé → Enregistrement` :
- `Format` : QuickTime Movie (.mov)
- `Encodeur` : Apple ProRes
- `Préréglage` : **422 HQ** suffit ici — pas besoin de 4444, il n'y a pas
  encore d'alpha à cette étape, juste besoin d'une image sans artefacts de
  compression pour que l'incrustation soit propre.

Crée une scène qui ne contient **que** cette source, bascule dessus, démarre
l'enregistrement, clic droit sur la source → **Actualiser** pour relancer
l'animation depuis 0, laisse-la finir, arrête l'enregistrement.

**2. Importer dans Resolve**
Nouveau projet → glisse le `.mov` dans le media pool → sur la timeline.

**3. Incruster le fond**
Page **Étalonnage (Color)** → ajoute un nœud **Qualifier** (ou **Ultra Key**
en mode chrominance) sur le clip → avec la pipette, sélectionne le fond
sombre uni du stinger (RGB ≈ 11, 7, 19 si tu veux le rentrer à la main).
Comme le panneau qui balaie l'écran est blanc/pastel — à l'opposé du fond en
teinte et en luminosité — un qualifier basique isole déjà quasiment
parfaitement les deux. Inverse la sélection si besoin pour garder le
panneau et exclure le fond.

Vérifie particulièrement les bords flous du panneau (là où le halo se
dissout dans le noir) : un léger dégradé résiduel à cet endroit est normal
et même cohérent visuellement, puisque c'est censé être un halo lumineux qui
s'estompe — pas besoin d'un bord parfaitement net comme pour un incrustation
de personne.

**4. Exporter avec alpha**
Page **Livraison (Deliver)** :
- `Format` : QuickTime
- `Codec` : **ProRes 4444**
- Coche l'option d'export du canal alpha (le nom exact varie selon la
  version — cherche "Alpha" dans les réglages du codec, elle n'apparaît que
  pour les formats qui le permettent)
- Exporte.

**5. Monter le stinger dans OBS**
`Transitions` → **+** → *Stinger* → sélectionne ce nouveau `.mov` → règle
**Transition Point** sur `duration / 2` en ms (450 ms pour la durée par
défaut de 900 ms, donnée exacte par `?debug=1`).

C'est plus de travail que la méthode par défaut (fond opaque), mais bien
plus fiable qu'un export alpha direct depuis OBS — si le résultat n'est pas
concluant, c'est visible et corrigeable dans Resolve plutôt que silencieux.

## 8. Vraie réfraction du verre (`shaders/liquid-glass-refract.shader`)

⚠️ **Complètement différent du reste du projet.** Tout ce qui précède est du
HTML/CSS servi par `server.py` et ajouté dans OBS comme source Navigateur. Ce
shader-là n'est **ni servi ni navigable** — c'est un filtre GLSL/HLSL à
appliquer directement dans OBS, via le plugin communautaire
**obs-shaderfilter**. Aucune de tes autres sources n'a besoin de ce fichier ;
il ne remplace rien, il ajoute une possibilité à part.

### Pourquoi un fichier séparé plutôt qu'un ajout au reste de la stack

Le CSS `.glass`/`.glass-strong`/`.glass-solid` utilisé partout ailleurs est
une **imitation** du verre — dégradés, bordures lumineuses, aberration
chromatique statique. Ce n'est pas une vraie réfraction, parce qu'une page
HTML servie comme source Navigateur **n'a jamais accès aux pixels réels**
qu'OBS place derrière elle (voir "Important à savoir sur le blur" plus haut).

Un filtre shader, lui, s'exécute **dans le pipeline de rendu d'OBS**, après
que ta webcam a été composée — il a donc un vrai accès aux pixels à déformer.
C'est la seule manière technique d'obtenir une réfraction qui réagit
réellement à ce qu'il y a sous le cadre.

### Mise en place

1. Installe **obs-shaderfilter** (plugin tiers, gratuit) :
   https://obsproject.com/forum/resources/shaderfilter.1736/
2. Groupe ta source webcam seule dans la scène (clic droit → grouper).
3. Clic droit sur ce groupe → Filtres → **+** → filtre Shader → charge
   `shaders/liquid-glass-refract.shader`.
4. Les curseurs (dépoli, force de réfraction, aberration chromatique, teinte,
   épaisseur, rayons intérieur/extérieur…) apparaissent directement dans les
   propriétés du filtre OBS — c'est ton contrôle "dépoli ↔ transparence
   totale", réglable en direct sans toucher au fichier.

Le curseur **`corner_radius_outer`** à 0 donne le même look "coins bouchés"
que `widgets/frame.html?corners=plug` ; à la même valeur que
`corner_radius_inner`, il donne le look `round` (rayon uniforme).

⚠️ **Non testé de mon côté** — aucun accès à OBS pour compiler ou visualiser
ce shader. La géométrie (SDF de rectangle arrondi, gradient pour la
réfraction, mélange net/flouté pour le dépoli) est mathématiquement solide,
mais un détail de syntaxe peut ne pas passer selon ta version d'OBS ou du
plugin. Dis-moi précisément ce qui se passe (erreur de compilation, rendu qui
ne ressemble à rien, plantage) et on itère ensemble.

## 9. Piloter le serveur depuis le Stream Deck (`bin/`)

Toute la stack (chat, alertes, minuteur, Spotify) dépend d'un seul processus
`server.py` qui doit tourner en arrière-plan. `bin/` fournit de quoi le
démarrer, l'arrêter, et vérifier son état **directement depuis un bouton
Stream Deck** — sans terminal visible, avec une notification macOS à chaque
appui pour confirmer ce qui s'est passé.

### Ce qu'il y a dans `bin/`

| Fichier | Rôle |
|---|---|
| `server-start.sh` / `server-stop.sh` / `server-status.sh` | la logique réelle, testable en ligne de commande |
| `Start Server.app` / `Stop Server.app` / `Toggle Server.app` / `Server Status.app` | ce que tu pointes depuis le Stream Deck |
| `make-apps.sh` | recompile les `.app` si tu modifies un `.applescript` ou déplaces le projet |

Les scripts `.sh` sont **idempotents** : démarrer un serveur déjà lancé ne
duplique rien (détection du port), arrêter un serveur déjà arrêté ne plante
pas. Testé explicitement dans les deux sens, y compris à travers les `.app`
compilées.

### Pourquoi des `.app` et pas les `.sh` directement

Un `.sh` lancé par le Stream Deck ouvrirait une fenêtre Terminal visible à
l'écran — pas terrible en plein live. Les `.app` sont de petits wrappers
AppleScript (`do shell script`) qui exécutent le script en silence et
affichent le résultat en **notification macOS** à la place.

### Configuration Stream Deck

Pour chaque bouton : action **Système → Ouvrir**, cible le fichier `.app`
correspondant (pas le `.sh`). Deux dispositions possibles :

- **Un bouton par action** : `Start Server.app` + `Stop Server.app`
  (+ éventuellement `Server Status.app` pour vérifier sans rien changer)
- **Un seul bouton bascule** : `Toggle Server.app` — démarre si arrêté,
  arrête si en route

### Retour visuel par notification (ce que fait `bin/`)

La **notification macOS** à chaque appui donne une confirmation immédiate
("démarré", "déjà lancé", "arrêté", "échec du démarrage — voir
`.server.log`"). C'est un retour **actif** (tu appuies, tu vois le résultat),
pas un indicateur ambiant en permanence allumé sur le bouton. Pour un vrai
indicateur permanent, voir la section suivante.

Si le port `5500` ne te convient pas, tous les scripts l'acceptent en premier
argument (`server-start.sh 5501`) — mais il faudrait alors éditer le port en
dur dans les `.applescript` correspondants et relancer `make-apps.sh`.

## 10. Vrai plugin Stream Deck avec icône live (`streamdeck-plugin/`)

Un bouton unique dont l'**icône reflète l'état réel du serveur en
permanence** (rond gris = arrêté, rond vert = en route — sondé toutes les 4
secondes, pas seulement à l'appui), et qui bascule démarré/arrêté au clic.
C'est le vrai plugin Stream Deck (SDK Elgato officiel) évoqué comme piste
plus tôt — construit avec le CLI et le SDK officiels, **compilé et validé
avec succès** (`streamdeck validate` → 0 erreur, 0 avertissement).

### Ce qui a été vérifié, et comment

Contrairement au shader GLSL, ce plugin a pu être construit avec de vrais
outils de vérification :

- **Le schéma JSON réel** (`@elgato/schemas`, package officiel) a été inspecté
  directement plutôt que deviné — champs requis, formats d'UUID, tailles
  d'icônes exactes.
- **Le template officiel** (`@elgato/cli`) a servi de base exacte pour la
  structure du projet (TypeScript + Rollup), pas une reconstruction à la
  main.
- **L'API du SDK** (`@elgato/streamdeck`) a été vérifiée contre ses vrais
  fichiers de types (`.d.ts`) installés localement — chaque méthode utilisée
  (`setState`, `onKeyDown`, `onWillAppear`, `registerAction`…) existe
  réellement avec cette signature. Ça a d'ailleurs attrapé une vraie erreur
  de typage (`DialAction` n'a pas `setState`, contrairement à `KeyAction`)
  avant même la compilation.
- **`npm run build` a réellement compilé** sans erreur.
- **`streamdeck validate` est passé** sur le plugin compilé.
- **La logique métier** (sonde HTTP + appel des scripts `bin/*.sh`) a été
  testée en dehors du plugin, dans les mêmes conditions, avec un vrai
  changement d'état du serveur pendant le test (arrêté → démarré → confirmé
  en route).
- **Les icônes** ont été vérifiées pixel par pixel aux dimensions exactes du
  schéma (20/40, 28/56, 72/144, 256/512).

**Ce qui n'a PU être testé** : le comportement réel une fois chargé *dans*
l'application Stream Deck elle-même (spawn du process, connexion WebSocket,
rendu visuel du bouton, réception du clic) — ça demande l'app Stream Deck en
étant connecté à un boîtier, que je n'ai pas. C'est une surface bien plus
petite que ce qui restait à vérifier pour le shader, mais reste la seule
inconnue réelle.

### Installation

1. Double-clique sur `com.majid.twitch-server-control.streamDeckPlugin` (livré
   séparément) — Stream Deck l'installe automatiquement.
2. Glisse l'action **Twitch Server Control** sur un bouton.
3. C'est tout — pas de configuration, les chemins et le port sont en dur pour
   cette install précise.

Si tu modifies le code (`streamdeck-plugin/src/`), recompile avec
`npm run build` puis relance la validation avant de re-packager :
```bash
cd streamdeck-plugin
npm run build
npx @elgato/cli validate com.majid.twitch-server-control.sdPlugin
npx @elgato/cli pack com.majid.twitch-server-control.sdPlugin -f
```

## Astuce générale OBS

Pour toutes les sources : dans les propriétés de la source Navigateur, décoche
**"Arrêter la source quand elle n'est pas visible"** pour le chat et les
alertes (sinon la connexion WebSocket se coupe en changeant de scène). Pour
les écrans de transition en revanche, tu peux la laisser cochée pour économiser
des ressources.
