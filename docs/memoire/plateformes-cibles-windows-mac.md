---
name: plateformes-cibles-windows-mac
description: "Les écoles tournent sous Windows 10/11 et Mac récents — Linux n'est PAS une cible de production, seulement la machine de dev"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-08-03T08:23:32.796Z
---

**Les postes des écoles sont sous Windows 10/11 et macOS récent. Linux n'est PAS une cible de production** (dit par le user le 2026-07-17 : « l'app ne tournera pas sous linux, ne t'inquiete pas car les ecoles utilise que windows 10,11 et mac version recente »).

**Why:** rien dans le dépôt ne le dit — tout le développement, l'empaquetage `.deb` ([[desktop-packaging-deb]]) et les tests GUI ([[gui-testing-linux]]) se font sous Linux, ce qui donne l'illusion que Linux est la cible. L'iMac de dev sous Cinnamon/X11 est un **environnement de développement**, pas un aperçu du parc réel.

**How to apply:**
- Ne pas investir dans les bugs spécifiques Linux (pilotes GPU, GTK, empaquetage `.deb`) : ils ne toucheront aucune école. Les traiter comme confort de dev, pas comme incidents de prod — arbitrer vite, ne pas s'acharner.
- Le `.deb` reste utile pour tester sur ce poste, mais **ne mérite pas de compromis** qui dégraderaient le code applicatif.
- Le travail de release qui compte = **Windows d'abord**. ⚠️ **Décision du 2026-08-03 : macOS est REPORTÉ après le déploiement** ; le dossier `epilote/macos/` n'existe même pas. La chaîne Windows, elle, est en place depuis le 2026-08-03 → [[chaine-livraison-windows]].
- Corollaire : un plantage observé sous Linux doit d'abord être qualifié « spécifique plateforme ou non ? » avant tout effort — cf [[desktop-packaging-deb]] (crash GPU nouveau = pilote Linux, invisible pour les écoles).
