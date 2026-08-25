---
name: profil-source-de-verite-droits
description: "Réconciliation rôle vs profil d'accès — la donnée sensible suit désormais le PROFIL (capacités dénormalisées + sync-rules par capacité), pas le rôle"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

✅ 2026-06-20 — Décision actée + Phase 1 livrée : **le profil d'accès devient la source de vérité des droits** ; le rôle reste le métier/identité. N'importe quel rôle peut recevoir n'importe quel profil (ex. enseignant + profil Comptable) et obtenir RÉELLEMENT la donnée correspondante hors-ligne.

**Contexte / conflit résolu** : avant, le client gatait l'UI par `profile_permissions` (verrou 3, `myPermissionsProvider`) MAIS la donnée SENSIBLE était synchronisée par RÔLE dans les sync-rules (`sensitive_<role>` `WHERE role='X'`). → un enseignant+profil Comptable voyait le module Finance mais VIDE (aucune donnée sync). Découverte live : la RLS des tables sensibles (`*_tenant`) est **tenant-only** (group+school, AUCUN contrôle de rôle/profil) → la protection par rôle vivait UNIQUEMENT dans les sync-rules. Donc rendre la donnée pilotée par le profil = changement sync-rules + un flag dénormalisé, sans réécrire la RLS pour que ça fonctionne (durcissement RLS = optionnel/futur).

**Migration `database/migrations/0005_profile_sensitive_scopes.sql` (APPLIQUÉE prod, vérifiée)** :
- 3 colonnes booléennes sur `profiles` : `sync_finance`, `sync_discipline`, `sync_medical`.
- Dérivées du profil d'accès via `can_read` sur slugs : finance/RH = `depenses|budget|personnel|presences-personnel|conges|paie` → (payroll, expenses, budget_lines, staff_members) ; discipline = `discipline` → discipline_incidents ; medical = `infirmerie` → infirmary_visits. (frais-scolarite/paiements-eleves NON sensibles, restent by_school.)
- Fonction `recompute_sensitive_flags_for_profile(uuid)` + trigger BEFORE sur `profiles` (UPDATE OF access_profile_id) + trigger AFTER sur `profile_permissions` (recalcule tous les membres du profil) + backfill.
- Vérif live : 0 incohérence sur 88 membres, 0 fuite (membres sans profil = tous flags false). Répartition : 12 finance / 31 discipline / 20 médical sur 111 profils (88 avec profil).

**Sync-rules `powersync/config/sync-rules.yaml` (✅ DÉPLOYÉES 2026-06-20)** :
- 6 buckets `sensitive_proviseur/directeur/comptable/cpe/surveillant/infirmier` → remplacés par 3 buckets par capacité : `sensitive_finance` (`WHERE sync_finance=true`), `sensitive_discipline`, `sensitive_medical`. 10 buckets au total. Validé + déployé via CLI.
- **CLI 0.10.0 (syntaxe à jour)** depuis `powersync/` : `PS_ADMIN_TOKEN=<pat> npx powersync deploy sync-config --directory=. --instance-id 6a185941234fa2bf51a66757 --sync-config-file-path config/sync-rules.yaml`. ⚠️ `--directory=.` obligatoire (défaut « powersync » → cherche un sous-dossier). `--project-id` = no-op. PAT fourni par l'utilisateur. Cf. [[powersync-status]] [[sync-rules-data-protection]].

**RLS durcie — migration `0006_rls_sensitive_by_capability.sql` (✅ APPLIQUÉE + TESTÉE)** :
- Helpers `auth_sync_finance/discipline/medical()` (lisent profiles par auth.uid()).
- 6 policies `*_tenant` : branche personnel `school_id=auth_school_id()` → `… AND <capacité>()`. super_admin + admin_groupe INCHANGÉS.
- `staff_members` = finance-only (colonnes job_title/base_salary_xaf/iban ; **AUCUN lien profil** : pas de profile_id → le code Dart `myStaffIdProvider` (WHERE profile_id) est un BUG LATENT à corriger lors de l'espace enseignant ; own_classes non utilisé en prod).
- ⚠️ Piège psql rencontré : pas de BEGIN/COMMIT global → un échec en milieu de fichier laisse des policies droppées non recréées (staff_members brièvement sans policy = verrouillée). Toujours wrapper les migrations multi-policies dans une transaction OU vérifier l'état après.
- Test RLS live (SET ROLE authenticated + request.jwt.claims) : membre finance voit 15 staff de son école ✓ ; membre sans capacité même école voit 0 ✓ ; admin_groupe voit 84 (groupe) ✓.

**État après déploiement attendu** : un directeur/comptable doit avoir un profil d'accès accordant les modules sensibles pour garder la donnée (cohérent : sans profil, sidebar déjà vide via verrou 3). Pas de régression réelle (≈95% comptes sans profil ne voyaient déjà rien).

**Aucun changement Dart nécessaire pour le cœur** (verrou 3 pilote déjà l'UI). Options Phase 1 restantes : aligner Calendrier natif (`app_shell.dart:313` gaté `directionRoles`) sur le profil ; UX formulaire (résumé « ce profil donne accès à… »).

**Phase 2 — branchements** : DÉCOUVERTE 2026-06-20 — communication DÉJÀ câblée pour le staff dans `app_shell.dart` + `app_router.dart` : `Routes.annonces`→StaffAnnouncementsScreen, `messagerie`→StaffMessagesScreen, `userSupport`→SupportRequesterScreen (Tickets), `userParametres`→UserSettingsScreen, `calendrier`→SchoolCalendarScreen, `evenements`→StaffAnnouncementsScreen(tab 1). RESTE réellement : **Rapports** (`userRapports`=StaffComingSoonScreen placeholder) et **Journal d'audit** (aucune route staff) → décider outils natifs direction + sync `audit_logs` (group-scopé). Voir [[espace-ecole-coquille]].

**Poste partagé (2 users même PC, ex. Proviseur+Comptable) — ✅ durci 2026-06-20** : `powersync_service.dart` appelait déjà `db.disconnectAndClear()` au `signedOut` (purge SQLite locale) MAIS en fire-and-forget → risque de course si le 2ᵉ user se connecte avant la fin de la purge. Fix : **file de sérialisation `_authQueue`/`_enqueueAuth`** → la purge du sortant se termine AVANT la connexion/synchro de l'entrant. Combiné aux sync-rules par capacité, chaque user ne reçoit que son périmètre. Résiduel honnête (non corrigé, rare) : crash en pleine purge ; session A persiste si A ne se déconnecte pas (politique d'auth, pas un bug sync). Durcissement futur possible : marqueur uid persistant + clear si mismatch au démarrage.
