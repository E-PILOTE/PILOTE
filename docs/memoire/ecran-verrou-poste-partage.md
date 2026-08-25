---
name: ecran-verrou-poste-partage
description: "Écran-verrou plein écran (kiosque) pour le changement d'agent sur poste scolaire partagé — livré + GUI-vérifié 2026-06-29"
metadata: 
  node_type: memory
  type: project
  originSessionId: 012e8fef-2c27-4d9d-a848-ba9c0832077f
  modified: 2026-07-24T06:15:11.181Z
---

✅ **2026-06-29 (branche `refonte/sidebar-shell`, 7 commits 3d1ac08→6f16419, NON fusionné)** — Écran-verrou plein écran « poste partagé », GUI-vérifié réel (Collège Public de Kinkala : lock au lancement → grille agents → pavé PIN création). Refonte du changement d'agent de [[poste-partage-agent-switch]].

**Principe** : remplace la page in-shell `/user/agents` (supprimée) par un **overlay anti-contournement** dans `MaterialApp.builder` (`AgentLockGate`), piloté par `needsAgentUnlockProvider`. S'impose **au lancement** (corrige le trou d'attribution : plus d'écriture « direction » par défaut) **et** sur demande via menu compte « Changer d'utilisateur » (qui pose juste `selectedAgentId=null`). Session Supabase appareil **jamais touchée** → 100% offline ; seul le PIN local déverrouille. « Déconnecter le poste » (vrai `auth.signOut`) reste dé-emphasé en bas.

**Public du verrou** = `agentLockApplies(role)` : personnel scolaire hors super_admin/admin_groupe/**parent/élève**. Repli anti-blocage : si aucun agent encore synchronisé → pas de verrou (jamais enfermé dehors).

**Fichiers** (tous `features/auth/`) : `providers/active_agent_provider.dart` (+`agentLockApplies`, `computeNeedsAgentUnlock`, `needsAgentUnlockProvider`) ; `screens/agent_lock_screen.dart` (orchestration grille↔PIN + en-tête école via `currentSchoolProvider` offline) ; `screens/widgets/{agent_lock_gate,agent_lock_background,agent_grid,agent_pin_pad}.dart`. Style login (auth_colors, AnimatedTricolorLine, logo.svg filigrane respiration sobre — contexte gouvernemental). Tests : `test/agent_lock_test.dart` (8) + `test/agent_lock_gate_test.dart` (2). analyze 0, build linux ✓.

**Reste (hors lot)** : geste direction « réinitialiser le PIN d'un agent » (libellé d'attente affiché) ; verrouillage auto après inactivité (écarté).

**🖥️ Refonte desktop (2026-07-23, commit `724bba8`)** — cibles = Windows/Mac clavier, pas tactile :
- **Saisie PIN au clavier physique**, panneau **ancré bas-gauche** façon mire Linux Mint / macOS (au lieu d'un pavé numérique à l'écran dans un modal centré). `agent_keypad.dart` **supprimé** (la saisie clavier était déjà gérée par `_onKey`) ; indice « Tapez votre code sur le clavier » ajouté ; `_RevealSheet` → `Align(bottomLeft)`, panneau étroit colonne unique, vitrine en décor.
- **Vitrine = profils ENRÔLÉS sur CE poste seulement** (ceux qui y ont un PIN local), plus tout l'annuaire de l'école — court, privé, rapide. Bouton « Autre profil — première connexion » → annuaire complet recherchable ; poste neuf (0 enrôlé) → annuaire d'emblée. Nouveau `AgentPinService.enrolledIds()` (scan clés `agent_pin_*`, exclut `agent_pin_set_at_*`) ; rangée « Récemment utilisés » retirée (redondante).
- Tests : flux adaptés, **goldens régénérés** (`lock_profils`, `lock_pin`). analyze 0, 374 tests.

**🎨 Refonte champ PIN + composition (2026-07-24, commit `25c301a`, GUI-vérifié réel)** — retour utilisateur « champ pas beau, veux simple » :
- Saisie = **vrai `TextField`** (hauteur normale, œil de visibilité À DROITE dans le champ, pattern mot de passe), fini les cases custom + le bouton « Afficher » séparé. Capte le clavier physique nativement (règle le focus). Auto-validation à 4, secousse, anti-force-brute conservés. `agent_keypad.dart` supprimé.
- En-tête = **carte d'identité** : avatar (photo/initiales) + nom + rôle (`roleLabel`).
- Composition **mire Mint/macOS** : vitrine = décor (assombrie 35 % seulement, horloge + branding visibles), efface son propre CTA « Ouvrir une session » + bandeau service quand le panneau monte (`revealProgress` passé à `VitrineShell`). Panneau ancré bas-gauche. Poignée bottom-sheet → simple « fermer ».
- ⚠️ Le hot-reload plante sur assertion sémantique (`!child.attached`) à cause du service d'accessibilité « Sous-titres instantanés » actif sur la machine dev — relancer FRAIS pour tester (le rendu initial est sain). GUI-test X11 : `xdotool windowfocus`+clic DANS le champ requis avant `type` (sinon la frappe n'atteint pas le TextField).

**Docs** : `docs/superpowers/specs/2026-06-29-ecran-verrou-poste-partage-design.md` + `docs/superpowers/plans/2026-06-29-ecran-verrou-poste-partage.md`.

Même branche : feature « sidebar fixe » (Communication épinglée bas + Tableau de bord ancré haut, drapeaux `pinned`/`pinnedTop`) commitée `988a69f`. Branche `refonte/sidebar-shell` toujours NON fusionnée dans main (rien poussé).
