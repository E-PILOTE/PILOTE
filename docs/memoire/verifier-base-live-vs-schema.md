---
name: verifier-base-live-vs-schema
description: database/schema.sql du repo est PÉRIMÉ — vérifier la base Supabase live via MCP avant de conclure sur RLS/colonnes/triggers
metadata: 
  node_type: memory
  type: feedback
  originSessionId: aacc8667-eedb-4396-9d75-f8ea5eb7d79c
---

`database/schema.sql` n'est **PAS** la source de vérité : il diverge de la base déployée (RLS et colonnes manquantes/différentes).

**Why:** vérifié en session 2026-05-31 — `schema.sql` n'avait AUCUNE policy pour `class_enrollments`/`academic_years`/`student_tutors`/`staff_members` etc., laissant croire à un default-deny ; la base live a en réalité une policy `*_tenant` correcte sur chacune. Conclure depuis le seul `schema.sql` aurait produit un diagnostic faux.

**How to apply:**
- Avant toute affirmation sur RLS, colonnes, contraintes ou triggers, **interroger la base live** via le MCP Supabase (`execute_sql`, project_id `wqpdamlnrwgozfvzjjpo`) : `pg_policies`, `information_schema.columns`, `information_schema.triggers`, `pg_get_functiondef`.
- Traiter `schema.sql` comme une intention historique, pas l'état réel.
- Connexion MCP confirmée fonctionnelle (lecture). Voir [[inscription-module-logique]], [[role-admin-groupe]].
