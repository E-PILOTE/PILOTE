---
name: poste-partage-agent-switch
description: "Modèle appareil partagé hors-ligne — identité appareil + bascule d'agent local (PIN) ; agent actif pilote permissions UI + attribution"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

✅ 2026-06-21 — Architecture « poste partagé hors-ligne » (réalité Congo : 1 PC, plusieurs agents, internet rare). Résout le défaut du clear-on-logout (reconnexion offline impossible, purge des saisies non synchronisées).

**Modèle retenu (choix utilisateur)** : *appareil d'établissement + bascule PIN*, sensible présent localement mais UI-gaté + RLS.
- **Identité APPAREIL** = session Supabase (provisionnée 1× en ligne avec un compte direction = capacités larges → toutes les données école descendent ; connexion persiste, marche des semaines offline). Sert : synchro + token connecteur (upload) + RLS.
- **AGENT ACTIF** = sélection locale en mémoire (défaut = utilisateur appareil ; au redémarrage on redemande). Pilote : permissions/UI (verrou 3) + attribution des écritures (created_by/audit).
- **PIN** = verrou d'attribution (« qui est au clavier »), PAS auth crypto (impossible offline). Haché en local (shared_preferences, sha256 sel=profileId), JAMAIS synchronisé. Set à la 1ʳᵉ bascule par agent/appareil.

**Fichiers** :
- `features/auth/providers/active_agent_provider.dart` : `selectedAgentIdProvider` (StateProvider), `activeAgentIdProvider` (= selected ?? device user), `switchableAgentsProvider` (db.watch profiles école), `activeAgentAccessProfileIdProvider`, `AgentPinService` (hasPin/setPin/verifyPin/clearAll), `agentPinServiceProvider`.
- Redirections vers l'agent actif : `myProfileRowProvider` (user_profile_provider) ; `myPermissionsProvider` + `myStaffIdProvider` (permissions_provider) ; `app_shell` passe le profil de l'agent actif à `_staffNavItems` (via myProfileRowProvider).
- `features/user/screens/staff_agent_switch_screen.dart` : sélecteur (grille agents + initiales/rôle) + `_PinSheet` (créer/saisir PIN). Route `Routes.userAgents=/user/agents`. Entrée menu compte « Changer d'agent » (personnel only).
- crypto ^3.0.7 ajouté en dépendance directe.

**Sync-rules (DÉPLOYÉES)** : bucket `by_access_profile` (qui ne syncait que l'utilisateur appareil) SUPPRIMÉ → `access_profiles` + `profile_permissions` synchronisés par GROUPE dans `by_group` (volume minuscule) pour que le gating de CHAQUE agent marche offline. 9 buckets.

**Écritures/sync multi-agents** : le connecteur upload avec le token APPAREIL → la RLS voit l'identité appareil (direction = tout passe) ; l'app estampille created_by/updated_by = agent actif (audit honnête). Une seule file d'upload, une seule base → robuste à des semaines offline, remonte tout au retour réseau.

**Limites assumées** : sensible physiquement sur le PC partagé (UI-gaté + RLS serveur) ; attribution = best-effort (pas non-répudiation crypto) ; si l'appareil est provisionné avec un compte étroit, il ne télécharge que ses capacités (convention : provisionner en direction). analyze 0 / build ✓. Voir [[profil-source-de-verite-droits]] [[espace-ecole-coquille]].

⚠️ Reste à faire : attribution created_by/updated_by à câbler dans CHAQUE module à mesure qu'on les construit (helper = activeAgentIdProvider) ; bug latent myStaffIdProvider corrigé côté source d'id mais staff_members n'a pas de profile_id (own_classes à revoir) ; option future : gate de lancement forçant la sélection d'agent.

✅ 2026-06-21 (UI + cohérence affichage, TESTÉ EN LIVE) :
- **Sélecteur agent redesigné** (`staff_agent_switch_screen.dart`) : cartes blanches sobres à **accent latéral coloré** = palette PLATEFORME uniquement (`_agentPalette` = [kNavy, kGreen, kRed, bleu 0EA5E9, violet 7C3AED]), avatar (photo `CachedNetworkImage` sinon initiales dégradé), puce rôle, **téléphone + date de naissance + âge** (sync `date_of_birth` ajoutée : schéma local `powersync_schema` + projection `directory` des sync-rules REDÉPLOYÉE), recherche + tri (Nom/Rôle), entrée animée staggered, hover lift. **PIN = dialogue CENTRÉ** (`_PinDialog` via showDialog, plus de bottom sheet), couleur de l'agent. (1ʳᵉ refonte « arc-en-ciel » rejetée par l'utilisateur → revenue à la palette plateforme.)
- **Drapeau du Congo** dessiné en code (`core/widgets/congo_flag.dart`, CustomPainter vert/jaune/rouge diagonal, couleurs kGreen/kAccent/kRed) ajouté à droite des DEUX bandeaux navy (dashboard `_SchoolBanner` + en-tête sélecteur). Dashboard banner aussi enrichi (emblème école, halo, puces, point synchro pulsant).
- **Affichage suit l'AGENT ACTIF** : `app_shell` passe `activeProfile` (agent actif) à `_AppHeader` (avatar+nom+rôle haut-droite) ET `_SidebarFooter` ; bandeau dashboard salue l'agent actif (`myProfileRowProvider.firstName`). Vérifié live : bascule Aline(Directeur)→Casimir(Secrétaire) change blocs dashboard (Finances→Discipline), Accès rapide, en-tête « Casimir M. · Secrétaire », bandeau « Bonjour, Casimir ». PIN persiste au redémarrage (shared_preferences) → 2ᵉ accès = saisie (pas création).
- **Fix dev poste**: `linux/runner/my_application.cc` ouvre la fenêtre **maximisée** (`gtk_window_maximize`) → plus de redimensionnement manuel = plus de crash GPU software. analyze 0 / build ✓.
