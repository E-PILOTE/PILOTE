---
name: git-remote-unreachable
description: ✅ RÉSOLU — remote E-PILOTE/PILOTE renvoyait 404 par MAUVAIS COMPTE gh actif ; fix = gh auth switch -u E-PILOTE
metadata: 
  node_type: memory
  type: project
  originSessionId: de55222c-1881-4dc3-b19e-83b3e547dd7f
---

✅ **RÉSOLU le 2026-07-04.** Le 404 n'était PAS une suppression du repo : `E-PILOTE/PILOTE` (privé, défaut `main`) est **intact**. Cause = **mauvais compte gh actif** (`ramsesmelack-sys`, sans accès au repo). Le bon compte **`E-PILOTE` était déjà dans le keyring gh**, juste inactif.

**Fix appliqué** :
```
gh auth switch -u E-PILOTE -h github.com
gh auth setup-git -h github.com
git push origin main                       # ff 03e7f42 → 7b8900c
git push -u origin refonte/sidebar-shell   # nouvelle branche distante → da8a98c
```

Au 2026-07-04, tout le travail (Scolarité→RH + écran-verrou + refonte dashboard, y compris les 3 commits de la session) est **poussé et sauvegardé** sur GitHub. Si un 404 réapparaît : `gh auth status` puis rebasculer sur le compte `E-PILOTE`. Comptes présents dans le keyring gh : `ramsesmelack-sys` (défaut, PAS d'accès), `Ramses2025`, `E-PILOTE` (le bon), `epilot2026`, `couriermae` (échec). Reste 1 fichier WIP non commité : `powersync_connector.dart` (surfacer les échecs de sync à l'utilisateur, cf. [[inscription-validation-effectif-a-verifier]]).

Diagnostic initial : `origin = https://github.com/E-PILOTE/PILOTE.git` renvoyait 404 Repository not found car le compte gh actif n'était pas collaborateur.
