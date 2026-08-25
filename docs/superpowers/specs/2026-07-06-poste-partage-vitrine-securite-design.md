# Refonte de l'entrée du poste scolaire — vitrine de sécurité + profils animés

**Date** : 2026-07-06
**Statut** : validé (maquettes approuvées via compagnon visuel)
**Périmètre livré maintenant** : Phase 1 (100 % front, zéro backend). Phases 2-3 = specs séparées.

## Contexte & problème

L'écran-verrou « poste partagé » (`agent_lock_screen.dart` + widgets) identifie *qui est au clavier* sur un ordinateur mutualisé (réalité congolaise : beaucoup d'écoles publiques ont un seul poste). Défauts actuels :

1. **Disposition dense et peu accueillante** : petites tuiles 2 colonnes (avatars 40 px) dans une carte blanche qui défile.
2. **PIN sans standards mondiaux** : pas de clavier physique (poste desktop !), pas d'auto-validation, pas d'anti-force-brute, pas de secousse/feedback, pas de « afficher ».
3. **Modèle unique imposé** : le verrou s'applique *toujours* au personnel dès que des agents sont synchronisés — impossible de distinguer un **poste partagé** d'un **poste personnel** (friction absurde sur un ordi individuel).

## Décision produit

L'écran-verrou devient une **vitrine de sécurité institutionnelle** à deux états :

- **Au repos (vitrine)** — plein écran, *jamais de scroll* : co-branding 🇨🇬 MEPSA·METP + école, horloge sobre + « poste sécurisé », zone message de service (carrousel, données Phase 3), bouton unique **Ouvrir une session**, encart partenaire opt-in (Phase 3), pied « Propulsé par E-PILOTE », ligne tricolore Congo.
- **Révélé (au clic)** — le **modal profils** monte en fondu (animation staggered) ; en-tête recherche + récents *fixes*, liste du personnel qui **défile à l'intérieur du modal** ; choix → **pavé PIN**.

Le bouton « Ouvrir une session » est **contextuel** : poste partagé déjà authentifié → profils ; (login appareil email/mot de passe reste l'écran existant, restyle visuel optionnel ultérieur).

## Phase 1 — périmètre livré

### 1. Mode d'appareil (partagé vs personnel)
- `deviceModeProvider` (persisté `SharedPreferences: device_mode` ∈ {shared, personal}, null = non choisi).
- Choix au **1ᵉʳ lancement** après connexion appareil (personnel scolaire uniquement) ; modifiable dans **Paramètres**.
- `computeNeedsAgentUnlock` gagne un critère : verrou **seulement si mode = shared**. Mode personal → l'utilisateur connecté EST l'agent, aucun verrou.
- « Changer d'utilisateur » (menu header) : en mode personal, active un `forceAgentPickerProvider` (bool) → affiche les profils à la demande, remis à false à la sélection.

### 2. Vitrine (`vitrine_shell.dart`)
- Réutilise `AgentLockBackground` (fond institutionnel existant).
- Widgets internes : bandeau co-branding, horloge vivante (tick 1 s), zone message de service (masquée si liste vide en Phase 1), bouton « Ouvrir une session », encart partenaire (masqué si opt-in off), pied.
- Aucun scroll : tout contraint à la hauteur écran.

### 3. Modal profils (refonte `agent_grid.dart`)
- Feuille bornée qui **monte en fondu** ; en-tête « Qui utilise ce poste ? » + recherche (autofocus, filtre clavier) + rangée **Récemment utilisés** *fixes*.
- Corps **défilable interne** (grille avatars, `Scrollbar` desktop) — la page mère ne défile jamais.
- Apparition **staggered** des cartes (fondu + translation).
- Récents : horodatés en local (`agent_last_used_<id>` epoch), triés desc, cap 4.

### 4. Pavé PIN (`agent_pin_pad.dart` + nouveau `agent_keypad.dart`)
- **4 chiffres fixes**, **auto-validation** au 4ᵉ chiffre (plus de bouton valider).
- **Clavier physique** : 0-9 + pavé num saisissent, `Backspace` efface, `Enter` valide, `Échap` revient aux profils.
- **Secousse** (offset amorti) + vidage à l'erreur ; **bouton « Afficher »**.
- **Cooldown progressif** persistant, par agent : échecs 1-4 = erreur ; 5ᵉ = 30 s ; 6ᵉ = 60 s ; 7ᵉ = 2 min ; 8ᵉ+ = 5 min (plafond). Compte à rebours affiché, pavé grisé. Succès → RAZ.
- « Code oublié ? » informatif (direction/admin_groupe réinitialise — Phase 2).

### 5. Service `AgentPinService` (étendu, `active_agent_provider.dart`)
- `pinCooldown(int failCount) → Duration` **fonction pure testable**.
- `recordFail / failCount / lockedUntil / clearFails` (persistés).
- `recordUsage / recentIds` (récents).
- `setPin` écrit aussi `agent_pin_set_at_<id>` (préparation reset Phase 2).

### Découpage fichiers (règle ≤ 500 lignes)
`vitrine_shell.dart` · `vitrine_clock.dart` (horloge) · `agent_grid.dart` (modal profils) · `agent_pin_pad.dart` · `agent_keypad.dart` · `device_mode_screen.dart` + provider · extension service dans `active_agent_provider.dart`.

## Tests (TDD)
- `pinCooldown` : mapping échecs→durée (bornes 4/5/6/7/8+).
- `computeNeedsAgentUnlock` : matrice (mode shared/personal/null × hasAgents × selected × forcePicker).
- Round-trip service : setPin→verify, recordFail×N→lockedUntil, recents ordre desc + cap.

## Non-régression (« ne casse pas »)
- On ne touche PAS : `AgentLockGate` (wiring `main.dart` builder), modèle sécurité (session appareil + RLS), hachage PIN, sync-rules.
- Le hachage reste `sha256(profileId::pin)` (verrou d'attribution, pas auth crypto — assumé).
- ⚠️ PIN passé de 4-6 à **4 fixes** : un ancien PIN 5-6 chiffres devient inutilisable (entrée plafonnée) → couvert par « code oublié » / reset. Acceptable (espace personnel non déployé, PIN locaux).

## Phases suivantes (specs séparées)
- **Phase 2** : reset PIN par admin_groupe — migration `profiles.pin_reset_requested_at` + RLS + règle de sync + UI admin_groupe + réconciliation locale (`agent_pin_set_at`).
- **Phase 3** : surface éditoriale — table messages de service + placements partenaires (CRUD super_admin, opt-in), synchro offline, carrousel + encart dans la vitrine.
