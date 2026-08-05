---
name: dashboard-persona-ordering
description: "Dashboard école adaptatif — accès par permissions, ORDRE des blocs par CHARGE réelle (modules accordés), rôle = départage ; card identité agent+école"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

✅ 2026-06-21 — Tableau de bord personnel (`features/user/screens/user_dashboard_screen.dart` + parts) rendu pleinement adaptatif, **sans violer** [[profil-source-de-verite-droits]].

**Décision structurante (2 couches) :**
- **ACCÈS** = permissions (`myPermissionsProvider`). Inchangé. Le profil d'accès reste la source de vérité ; RIEN n'est hardcodé par rôle pour débloquer un bloc.
- **ORDRE des blocs = CHARGE RÉELLE**, PAS le titre de rôle. `enum _Section {scolarite,finance,medical,discipline}` + `_orderedSections(role, perms)` : poids par domaine déduit des modules accordés (`_sectionWeight` : `can_read`=+1, `can_write`=+2, `can_validate||can_approve`=+1 ; slugs par domaine dans `_sectionSlugs`), tri poids décroissant, **départage** à charge égale par `_roleTiebreak(role)` (comptable→finance, cpe/surveillant→discipline, infirmier→médical, sinon overview). Un bloc non permis ne s'affiche jamais.
- `_roleContextLabel(role)` → libellé en 3ᵉ ligne du bandeau (« Comptabilité », « Vie scolaire · CPE »…).

**Pourquoi CHARGE et pas rôle (correction d'un 1er jet role-based) :** l'admin groupe attribue les modules indépendamment du titre. Cas réels : pas de comptable → secrétaire/directeur reçoit la Finance ; comptable en CONGÉ → ses modules basculent au directeur. Le titre ne dit donc pas ce que la personne FAIT ; les modules accordés, si. Conséquence voulue : Finances **remonte automatiquement** chez qui reçoit ces modules, et **redescend** quand on les retire — zéro code, zéro changement de rôle. Extraction de `_ScolariteBlock` (widget) pour ordonnancement homogène avec Finance/Médical/Discipline.

**Vérifié LIVE 2026-06-21** (Collège Public de Kinkala, même école) : directrice Aline → Vue d'ensemble d'abord ; comptable Patrick (`comptable@kinkala.cg`, poids Finance=16 vs Scolarité=3, médical/discipline=0) → **Finances en tête, puis Scolarité, sans médical/discipline**. Ordre exactement inversé, confirmé à l'écran. (psql pooler `aws-1-eu-central-2` pour lire perms ; reset mot de passe via API admin BLOQUÉ par le classifieur auto-mode → l'utilisateur s'est connecté lui-même.)

**Card identité (bandeau bleu) :** gauche = photo AGENT ACTIF (`UserAvatarCircle` 64px, source `myProfileRowProvider` — poste partagé, cf [[poste-partage-agent-switch]]) ; droite = logo établissement cascade **école.logo_url → school_groups.logo_url (héritage groupe) → initiales** (`_SchoolLogoBadge` 64px, `currentGroupLogoProvider` — offline OK, lignes school_groups+schools déjà dans sync-rules) ; pied = liseré tricolore Congo. Doublons Année/À-jour retirés du bandeau (« À jour » déplacé sur la card verte `_AcademicYearCard` via `_SyncPill`).

**Correctifs même passe :** `_xaf()` gère négatifs (solde déficitaire) ; `_ChartLoading` (skeleton ≠ état vide pendant 1ʳᵉ synchro) ; graphe Élèves/classe scroll horizontal + rotation auto si >12 classes ; Semantics avatar+logo.

**Gap honnête restant (audit) :** pas de vue « Aujourd'hui » (présences du jour — dépend Phase 3 attendance) ; rien de spécifique enseignant (« mes classes du jour ») ; espace parent/élève squelettique. analyze 0 / build linux ✓.

**DETTE STRUCTURELLE CONNUE + DÉCISION 2026-06-21 :** le registre de sections est un `enum _Section` FERMÉ (4 domaines : scolarite/finance/medical/discipline) hardcodé en 4 sites (`enum`, `_sectionSlugs`, `_roleTiebreak`, les `show*`/`blocks` du build dans `user_dashboard_screen.dart`). Couvre ~6 slugs sur **28 modules / 6 catégories** réelles (catalogue live : enseignement, evaluation, finance, rh, scolarite, vie-scolaire — voir [[catalogue-modules-v2]]). Les blocs d'insight existants (finance/medical/discipline) ont de VRAIS providers (`dashboard_provider.dart` : student_payments / infirmary_visits / discipline_incidents) ; les 22 autres modules ne sont surfacés QUE comme lanceurs dans `_QuickModulesGrid` (aucun orphelin). **Décision tranchée (user a délégué « prends la main ») : NE PAS construire de registre data-driven ni de cartes « bientôt » maintenant** = généralité spéculative (coquilles vides recodées à chaque phase + mur de placeholders dégradant pour une app gouvernementale). **À la place : étendre le registre PHASE PAR PHASE**, au moment où chaque domaine livre son écran+provider (Phase 3 présences, Phase 4 évaluation/bulletins, Phase 5 rh/paie, Phase 6 cantine/biblio) — l'ajout d'enum est ~3 lignes co-localisées avec la vraie fonctionnalité. Si un jour >8-10 domaines, ALORS envisager un registre dérivé du catalogue. Dashboard considéré COMPLET vs ce qui est implémenté → on est passé à la suite (Phase 1 Structure).
