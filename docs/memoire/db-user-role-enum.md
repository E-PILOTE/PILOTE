---
name: db-user-role-enum
description: "Real values of the Postgres user_role enum — there is NO 'utilisateur' value (memory/CLAUDE.md were wrong)"
metadata: 
  node_type: memory
  type: project
  originSessionId: b9adb2ad-c65e-49c2-96b0-08a58aee1dd5
---

The `user_role` Postgres enum (table `profiles.role`) has these 13 values, in order:
`super_admin, admin_groupe, directeur, proviseur, enseignant, cpe, comptable, secretaire, surveillant, parent, eleve, infirmier, responsable_cantine`

**There is NO `'utilisateur'` value.** Earlier memory and `CLAUDE.md` claimed the enum was just `super_admin/admin_groupe/utilisateur` — that is FALSE and caused a broken RPC (a `create_school_user` that set `role='utilisateur'` threw `invalid input value for enum user_role`).

Role → app space mapping (see `_dashboardForRole` in `lib/core/router/app_router.dart`):
- `super_admin` → `/super/*` (Supabase direct)
- `admin_groupe` → `/admin/*` (Supabase direct)
- **everything else** (directeur, enseignant, comptable, …) → `/user/*` (PowerSync offline-first). The router uses a `default:` case, so "school staff" = any role ≠ super_admin/admin_groupe. The staff member's role IS their job; `access_profile_id` is a SEPARATE, optional permission layer.

`AppConstants.roleUtilisateur = 'utilisateur'` in `lib/core/constants/app_constants.dart` is a fiction — it never matches a real DB value. The router gate `role == roleUtilisateur` (app_router.dart:160) is dead code; the correct staff test is `role != super_admin && role != admin_groupe`.

**Why:** verified against live DB 2026-05-31 via `pg_enum`; existing data = 20 enseignant, 2 super_admin, 1 admin_groupe.
**How to apply:** when creating school-staff accounts, pass a real job role (enseignant/directeur/…). When listing a group's "users/personnel", filter `role not in ('super_admin','admin_groupe')`, not `= 'utilisateur'`. See [[role-admin-groupe]].
