---
name: gui-testing-linux
description: "Comment voir/piloter/screenshoter l'app Flutter Linux desktop moi-même (X11 + Dart VM Service)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1e049c31-2175-4605-89ef-5c434794a1b6
---

L'app E-PILOTE est un **Flutter desktop GTK (Linux X11, DISPLAY=:0)** — Chrome-devtools MCP ne marche pas dessus, mais je peux la voir et la piloter directement.

**Outillage installé (2026-06-09)** : `scrot`, `imagemagick` (`import`/`convert`/`identify`) via `apt` (sudo `‹secret — gestionnaire de mots de passe›`). `xdotool` + `wmctrl` déjà présents.

**Capturer l'écran** : `import -window <winid> /tmp/x.png` puis Read le PNG. Trouver la fenêtre : `wmctrl -lG | grep -i epilote` → id `0x06600003` (titre « epilote »). Recadrer une bande full-res : `convert in.png -crop WxH+X+Y +repage out.png` (le preview Read est down-scalé → cropper pour lire les détails/chiffres).

**⚠️ Clic = coordonnées RACINE, décalées par la décoration de fenêtre** : `import` capture la zone CLIENT (sans titre), mais `xdotool click` vise l'écran entier. Décalage haut = `_NET_FRAME_EXTENTS` (ici **top=32px**). **Méthode fiable = coordonnées RELATIVES fenêtre** : `xdotool mousemove --window <winid> <cx> <cy>` puis `xdotool click 1`. Calibrer avec `xdotool getmouselocation` (a confirmé client-origin root y=32). NE PAS se fier à `getwindowgeometry` (a renvoyé Y=72 erroné).
- **Scroll** : le wheel xdotool en coords **fenêtre** (`mousemove --window` puis `click 5`) NE scrolle PAS la vue GTK Flutter ; le clavier (Next/End) non plus. **CE QUI MARCHE** = coords **absolues écran** : placer la fenêtre à 0,0 (`windowmove 0x… 0 0`), `xdotool mousemove 1300 700` (pointeur sur le contenu), puis `xdotool click --repeat 45 --delay 12 5`. Sinon resizer très haut (`windowsize <winid> 1400 1340`) pour voir plus d'un coup.

**Inspecter les erreurs runtime (le plus puissant)** : le `flutter run` expose un Dart VM Service + DTD. Workflow MCP Dart :
1. `flutter run -d linux --debug > /tmp/epilote_run.log 2>&1 &` (background).
2. `mcp__dart__dtd listDtdUris` → récupère `ws://127.0.0.1:PORT/...` (Workspace Root = epilote).
3. `mcp__dart__dtd connect <uri>` → liste l'app connectée.
4. `mcp__dart__get_runtime_errors` → **donne l'assertion exacte** ; `hot_reload`/`hot_restart` (clearRuntimeErrors:true) pour itérer.
5. Le **run log `/tmp/epilote_run.log`** contient l'`EXCEPTION CAUGHT` formatée avec « The relevant error-causing widget was: … fichier:ligne » → bien plus exploitable que le blob `get_runtime_errors`. `grep -nE "EXCEPTION|error-causing|Failed assertion|infinite|overflow"`.

**Hot reload vs restart** : changements de corps de provider (FutureProvider keepAlive) ne se ré-exécutent PAS au hot reload (valeur cachée) → **hot_restart** pour re-fetch. Le restart **reset la route** → re-naviguer (cliquer la sidebar). Page blanche = exception en phase layout/build (en debug : pas d'écran rouge si c'est une assertion de layout dans un sliver, juste du blanc).

Cette boucle (run bg → screenshot → get_runtime_errors → grep log → edit → hot_restart → re-screenshot) m'a permis de diagnostiquer et corriger seul le bug page blanche des Années scolaires. Voir [[admin-groupe-espace]].
