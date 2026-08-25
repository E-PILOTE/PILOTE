---
name: migration-ledger-drift
description: database/migrations/0001-0024 appliquées via SQL brut mais ABSENTES du registre Supabase (dernière entrée = 2026-06-17)
metadata: 
  node_type: memory
  type: project
  originSessionId: de55222c-1881-4dc3-b19e-83b3e547dd7f
---

Le dossier `database/migrations/0001_*.sql → 0024_get_group_users_rh.sql` (24 fichiers : inscription, class_subjects 0014, EDT 0015-0022, holidays 0020, RH dossier 0023, capacité 0004, RLS sensibles 0005/0006, etc.) est le **vrai journal de travail**, mais **aucune de ces migrations n'apparaît dans `supabase_migrations` live** (`list_migrations` s'arrête à `20260617065020 fix_avatars_storage_rls`, daté 2026-06-17).

Ce que ça veut dire : ces migrations ont été **appliquées à la main via `execute_sql`/MCP** (pas `apply_migration`), donc **le schéma EST bien déployé en prod** — vérifié : les tables existent live avec données (`evaluations`, `grades`, `bulletins`, `staff_career`, `payroll`, `leave_requests`, `timetable_exceptions`, `class_subjects`… présentes). Mais le **registre de migrations ne les trace pas** → gap de reproductibilité : un rebuild depuis le ledger Supabase ne recréerait pas ces objets.

Le registre live (49 entrées) = bootstrap `001..019` (26 mai) + correctifs horodatés jusqu'au 17 juin. Le schéma numéroté `00XX` du repo est un système parallèle non réconcilié.

**Action de dette** : soit ré-enregistrer les 0001-0024 comme migrations officielles (`apply_migration` idempotent), soit documenter que `database/migrations/` est la source de vérité et le ledger Supabase secondaire. Cf. règle projet « vérifier la base live » [[verifier-base-live-vs-schema]].
