---
name: reprise-du-poste
description: "🔑 Une session serveur morte n'enferme plus l'école dehors — jeton miroir au coffre, reprise hors ligne au PIN ; ⚠️ un `tokenRefreshed` sans `signedIn` doit reconnecter PowerSync"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T12:32:37.576Z
---

# Reprise du poste (2026-08-04)

Suite de [[deconnexion-subie-nefface-pas]] : garder la base ne suffisait pas,
le poste retombait quand même sur l'écran **e-mail + mot de passe** que
personne dans une école ne connaît (les agents n'ont qu'un PIN à 4 chiffres).

## Trois portes, dans cet ordre

0. **Reprise silencieuse** — le `refreshToken` est recopié dans
   `flutter_secure_storage` à chaque session valide, puis rejoué au démarrage
   par `setSession()` si `currentSession == null`. Cas le plus fréquent :
   personne ne voit rien. ⚠️ gotrue persiste déjà la session complète en clair
   dans SharedPreferences — le miroir au coffre n'affaiblit rien.
1. **Reprise hors ligne** — `porteDeReprise(sessionOuverte, posteConnu,
   donneesLocalesPresentes)` : les deux dernières conditions sont CUMULATIVES
   (se souvenir sans les données ouvrirait une app vide qui a l'air cassée).
   L'écran `/reprise-poste` nomme l'école (lue en local), un agent enrôlé entre
   son PIN → `reprendreHorsLigne()` charge le profil du SQLite local. Les
   écritures s'empilent dans `ps_crud`.
   ⚠️ `exigePinPourReprise(0) == false` : sur un poste PERSONNEL aucun PIN
   n'existe jamais — exiger un code jamais créé enfermerait à coup sûr.
2. **Reconnexion** — mot de passe, adresse préremplie et NON modifiable :
   ouvrir une session avec un autre compte purgerait la base (multi-tenant).

`sessionKeeper.oublier()` seulement sur déconnexion VOLONTAIRE.

## ⚠️ Le piège qui a failli passer

`setSession()` émet **`tokenRefreshed`**, PAS `signedIn`. L'ancienne branche
ne faisait que `prefetchCredentials()` *si déjà connecté* → le poste
retrouvait son compte mais **restait désynchronisé jusqu'au redémarrage**.
Désormais `tokenRefreshed` + non connecté → `_connecterSiPersonnel()`.

Idem UI : `syncIndicatorProvider` dit « Synchronisé » dès qu'une synchro a
réussi UN JOUR → contredisait la bannière. Forcé à « Hors ligne » quand
`modeHorsLigneProvider`.

## Recette (Linux, reproductible)

```bash
# porte 0 : supprimer la session persistée
python3 -c "import json;p='~/.local/share/cg.epilote.epilote/shared_preferences.json';d=json.load(open(p));d.pop('flutter.sb-wqpdamlnrwgozfvzjjpo-auth-token');json.dump(d,open(p,'w'))"
# porte 1 : + retirer 'epilote_refresh_token_v1' du blob libsecret
#   (item « cg.epilote.epilote/FlutterSecureStorage », via gi.repository.Secret)
```

Tests : `test/reprise_poste_test.dart` (11). Liens :
[[offline-device-enrollment]] · [[poste-partage-agent-switch]]
