---
name: abonnement-infra-reelle-hardlock
description: "L'infra abonnement (plans/modules/facturation) EXISTE déjà en prod ; hard-lock impayé privé livré (ADR-0009)"
metadata: 
  node_type: memory
  type: project
  originSessionId: f2f8f15d-283d-495c-ad0f-3942b139fecb
---

⚠️ **L'infrastructure d'abonnement existe DÉJÀ en production** — ne jamais croire qu'elle manque (mon analyse d'archi 2026-07-05 l'a affirmé à tort en se fiant à une note périmée). Vérifié dans le code app qui tourne en prod + `database/schema.sql` :

- `subscription_plans` (id, name, slug=`plan_slug` enum, price_xaf, max_schools/students/staff, module_count, is_public_plan, is_active) — page super_admin `plans_provider.dart` branchée.
- `modules` (category_id→`module_categories`, slug, is_active, display_order) + `module_categories`.
- `plan_modules` (plan_id, module_id, UNIQUE) — rattachement N↔N.
- `group_invoices` (invoice_number, amount_xaf, status=`invoice_status`, payment_method, paid_at) — **facturation existante**.
- `platform_settings` = 1 ligne (id=1) avec blob `data` jsonb : contient `grace_days`, `due_days`, `notif_reminder_days`, flags notif. Réglages via `platform_settings_provider.dart`.
- Contrat = `school_groups.plan_id` (NOT NULL FK) + `subscription_status` + `subscription_start/end`. **Un seul plan actif par tenant** (dénormalisé, design volontaire). Table `subscriptions` séparée INEXISTANTE (et inutile). Voir [[abonnement-etat-reel-enforcement]].

**Conséquence** : pour faire évoluer l'abonnement, souvent **ZÉRO migration** — ajouter des clés dans `platform_settings.data` ou réutiliser `is_public_plan`.

**Hard-lock impayé LIVRÉ le 2026-07-05 (ADR-0009, non commité)** — décision produit : le read-only ne pressait pas assez au paiement (marché où l'impayé est opportuniste).
- Nouvelle `LicensePhase.hardLock` (> readOnly) : passé la grâce (J+15), **modules inaccessibles** → mur `/user/renouvellement` (`RenewalWallScreen`) ; seuls Dashboard/Profil/Paramètres/natifs restent. Écriture déjà bloquée.
- **Privé uniquement** : déclenché ssi licence porte `hard_lock=true` (émetteur = `NOT is_public_plan`). Écoles publiques/État MEPSA/METP JAMAIS bloquées (risque politique). Défaut `hardLockable=false` = fail-soft, aucune régression pilotes.
- **Impayé confirmé seulement** : la fenêtre de confiance offline n'escalade jamais au-delà de readOnly (réseau ≠ impayé). Synchro jamais gatée (C4).
- **LIVRÉ & MERGÉ EN PR #8** (branche `feat/licence-hardlock-impaye`, commit `1e49d65`) le 2026-07-05 :
  - Domaine : `LicensePhase.hardLock`, `License.hardLockable` (claim `hard_lock`), `Entitlement.isHardLockedAt`, `LicenseEnforcement.isHardLockedNow`.
  - Routeur `app_router.dart` : module → `Routes.userRenew` si `isHardLockedAt` (avant verrou plan). `RenewalWallScreen` (neutre, aucun PowerSync).
  - Sidebar clic mort : `NavTile.locked` (grisé + cadenas + curseur interdit + onTap no-op), câblé `app_sidebar.dart` via `moduleSlugForLocation(route)!=null` (dashboard/profil/natifs jamais verrouillés).
  - Edge Function `license-issuer/index.ts` : émet `hard_lock: plan.is_public_plan === false` (fetch `subscription_plans.is_public_plan`).
  - Tests : +9 domaine, +3 NavTile (`nav_tile_locked_test.dart`), +3 intégration sidebar réelle (`sidebar_hardlock_test.dart` : privé→cadenas, public→rien, dormant→rien). analyze 0, build Linux debug OK.
- **RÉVISÉ 2026-07-05 (choix propriétaire) : hard-lock UNIFORME (public=privé) + blocage LE JOUR MÊME (plus de grâce).** Edge Function émet `hard_lock: true` pour tout groupe ; `computeLicensePhase` → hardLock dès `overdue>=0` si `hardLockEligible`. La grâce 15 j ne subsiste que dans le chemin fail-soft (flag absent). Zone neutre (dashboard/profil/renouveler/communication) reste ouverte. **PR #8 MERGÉE dans main (`598ca7f`) le 2026-07-05.** Suite complète post-merge : 71 verts / 2 rouges (géo Overpass externe pré-existants), analyze 0, app boote proprement (écran agent Kinkala vérifié GUI).
- **Edge Function `license-issuer` DÉPLOYÉE le 2026-07-05 (version 7, ACTIVE)** via Management API (curl multipart `POST /v1/projects/{ref}/functions/deploy?slug=license-issuer`, `verify_jwt:true` préservé). ⚠️ CLI npm `supabase` CASSÉ (pas de binaire linux-x64) → passer par la Management API. Le hard-lock est donc **actif en prod** pour qui reçoit une licence (gating `LICENSE_PILOT_GROUP_IDS` inchangé). Reste : release de l'app Flutter (domaine same-day) pour que le comportement client suive.
- ⚠️ **SECRETS EXPOSÉS EN CHAT le 2026-07-05** (management token sbp_, anon, service_role, mdp DB) — rotation à faire/vérifier côté propriétaire.
- Artifact d'archi CORRIGÉ (les statuts « Manquant » plans/modules/facturation étaient faux). Voir [[licence-socle-implemente]].
