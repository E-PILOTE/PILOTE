---
name: db-scale-hardening
description: "Durcissement base nationale (index FK, intégrité, RLS init-plan) — appliqué 2026-06-08"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1e049c31-2175-4605-89ef-5c434794a1b6
---

Audit d'expert « système gouvernemental national » (preuves = Supabase advisors). Appliqué en prod le 2026-06-08 (3 migrations, autorisées par l'utilisateur) :

- **Migration `index_all_unindexed_foreign_keys`** : DO-block dynamique idempotent qui crée un index btree sur CHAQUE clé étrangère non couverte. **171 FK non indexées → 0** (advisor perf). C'était le risque d'échelle n°1 (jointures/filtres `academic_year_id`/`school_id`/`group_id`/`student_id`/`class_id`/`enrollment_id`… en scan de table). ⚠️ Effet de bord bénin : « Unused Index » 36→207 (les nouveaux index n'ont pas encore servi sur la base de test ; ils serviront en prod — NE PAS les supprimer en se fiant à l'advisor).
- **Migration `academic_integrity_constraints`** : intégrité gravée en base (préchecks = 0 violation avant application) :
  - `uq_ay_current_group` UNIQUE `(group_id) WHERE is_current AND school_id IS NULL` — une seule année courante groupe.
  - `uq_ay_current_school` UNIQUE `(school_id) WHERE is_current AND school_id IS NOT NULL` — idem par école.
  - `uq_enrollment_active_student_year` UNIQUE `(student_id, academic_year_id) WHERE status='active'` — pas de double inscription active.
- **Migration `rls_initplan_wrap_auth_uid`** : 9 policies réécrites `auth.uid()` → `(select auth.uid())` (init-plan, éval 1×/requête au lieu d'1×/ligne). Sémantique identique. Tables : messages (msg_delete/insert/select/update), notifications (notif_access), profiles (profiles_select/update), school_projects (projects_insert), support_tickets (group_insert_tickets). **9 → 0** (advisor perf).

Constats POSITIFS confirmés : RLS activée sur 100% des tables ; sync-rules **bornées par école** (`p.school_id = x.school_id WHERE p.id=auth.user_id()` sur students/class_enrollments/grades/attendance_records/student_payments) → charge offline non group-wide ; tous les SECURITY DEFINER ont déjà `search_path` fixé (0 vulnérable).

## RESTE (roadmap, non appliqué — choix prudent)
- **76 « Multiple Permissive Policies »** : NON fusionnées en aveugle (risque de changer la sémantique d'accès sur système d'État) → revue par table requise.
- **Protection mots de passe fuités OFF** : toggle Auth dashboard (HaveIBeenPwned) — à activer pour un système gouvernemental. Pas faisable en SQL/MCP.
- **32 fonctions non-SECDEF sans `search_path`** : faible risque (aucune SECURITY DEFINER concernée).
- **#3 Rétention offline par année — DÉLIBÉRÉMENT NON FAIT** : borner les sync-rules aux années récentes (courante + N-1) **casserait la consultation hors-ligne des archives** (le combo année staff lit le SQLite local). Compromis assumé : à concevoir quand le volume multi-années l'exigera (archives anciennes → consultation EN LIGNE admin_groupe). Nécessite aussi un redéploiement dashboard PowerSync (hors agent).
