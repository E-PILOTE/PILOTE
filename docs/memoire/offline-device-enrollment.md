---
name: offline-device-enrollment
description: Verrouiller ≠ Déconnecter — la purge PowerSync ne doit jamais détruire du travail non synchronisé ; désenrôler un poste partagé est réservé à la direction
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

**Règle non négociable : on ne purge JAMAIS la base locale tant qu'il reste du travail non remonté.**

Incident du 2026-07-13 (réseau coupé + clic « Déconnexion ») : tout l'espace école devenait vide. Chaîne exacte —
1. `gotrue.signOut()` supprime la session locale et émet `signedOut` **avant** l'appel HTTP `/logout` ;
2. notre écouteur exécutait `db.disconnectAndClear()` → `powersync_clear()` → base locale **et file d'écritures en attente (`ps_crud`) EFFACÉES** ;
3. l'appel HTTP échouait ensuite → l'exception remontait → `state = null` jamais exécuté → app en **état zombie** (écrans du personnel, base vide).

Le pire n'était pas le clic : `signedOut` peut être émis **tout seul** (jeton de rafraîchissement invalidé après une longue coupure) → une école pouvait perdre sa journée **sans aucune action utilisateur**.

**Correctifs (commits `03367bd`, `efb1c01`, branche `feat/poste-vitrine-securite`) :**
- `pendingLocalWork()` (= `ps_crud` + `upload_outbox`) verrouille la purge ; à `signedOut` on fait `disconnect()` seul s'il reste quoi que ce soit. La purge multi-tenant a lieu au **signedIn d'un utilisateur DIFFÉRENT** (dernier user mémorisé dans SharedPreferences — hors PowerSync exprès, pour survivre à `powersync_clear` et au redémarrage).
- `AuthNotifier.signOut()` avale l'échec réseau du `/logout` (plus d'état zombie).
- **VERROUILLER ≠ DÉCONNECTER** : le bouton de sidebar détruisait l'**enrôlement de l'appareil** — un agent « se déconnectant proprement » sans réseau bloquait l'école entière. Sidebar = « Verrouiller » (local, hors-ligne) ; « Déconnecter ce poste… » relégué au menu compte avec avertissement explicite.
- `canUnenrollDevice(role, mode)` : poste **partagé** → `directeur`/`proviseur` seulement ; poste **personnel** → tout rôle ; doute (rôle nul, mode non choisi) → **refus**. Désenrôler n'est jamais urgent (appareil volé = révocation serveur), donc le réserver ne bloque rien.
- Trou colmaté : « Déconnecter le poste » figurait sur l'**écran-verrou**, donc accessible **sans PIN** — n'importe qui passant devant la machine pouvait débrancher l'école. N'y subsiste que si `agents.isEmpty` (secours poste neuf).

**Éteindre l'ordinateur ne détruit rien** : la session est persistée, l'app repart hors-ligne sur l'écran-verrou. Seul `signOut()` détruit l'enrôlement.

**PR #16** poussée (36 commits) : https://github.com/E-PILOTE/PILOTE/pull/16 — 207 tests verts, analyze 0, build Linux OK, migration 0038 appliquée+vérifiée en prod.

Voir aussi [[sync-failure-journal]], [[ecran-verrou-poste-partage]], [[poste-partage-agent-switch]], [[upload-outbox-fichiers]].
