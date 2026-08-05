---
name: auth-null-token-login-500
description: "Comptes créés par RPC bloqués au login (500 \"Database error querying schema\" → app affiche \"Pas de connexion internet\") ; cause = colonnes token NULL dans auth.users"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a40fc29-8762-4c8e-bbec-655c8bf3d09a
---

**Symptôme** : un compte créé côté serveur (admin_groupe, personnel école) échoue au login avec « Pas de connexion internet » dans l'app — alors que le réseau marche. super_admin (créé normalement) passe.

**Cause racine** (diagnostiquée 2026-07-08, paul@epilote.cg) : les RPC de création `create_admin_user` et `create_school_user` (×2 overloads) inséraient dans `auth.users` **sans** renseigner les colonnes token (`confirmation_token`, `recovery_token`, `email_change`, `email_change_token_new`, `email_change_token_current`, `phone_change`, `phone_change_token`, `reauthentication_token`) → elles restaient `NULL`. GoTrue les scanne en `string` Go (pas `sql.NullString`) → « converting NULL to string is unsupported » → **HTTP 500 `Database error querying schema`**. L'app le reçoit comme `AuthRetryableFetchException` et l'affiche via `_offlineLoginMsg` (« Pas de connexion internet »).

**Chaîne de classification trompeuse** : `auth_provider.dart::_isNetworkError` traite `AuthRetryableFetchException` comme réseau. Or gotrue-2.21 lève cette exception dans **exactement 2 cas** (`fetch.dart::_handleError`) : (1) `error is! Response` = vrai échec transport, (2) **statut HTTP ≥ 500**. Donc « Pas de connexion internet » = transport OU 5xx serveur. Toujours tester le endpoint token brut pour trancher : `curl .../auth/v1/token?grant_type=password` → lire le code HTTP.

**Fix livré** : migration `database/migrations/0036_fix_auth_null_tokens.sql` — (1) `UPDATE auth.users` COALESCE NULL→'' sur les 8 colonnes (106 comptes réparés), (2) les 3 fonctions insèrent désormais `''`. Appliquée + vérifiée en prod (still_null=0, login paul 200). ⚠️ **Piège dormant** : toute nouvelle RPC qui `INSERT INTO auth.users` doit renseigner ces 8 colonnes à `''`.

**Outillage** : la voie qui MARCHE sans OAuth = API Management Supabase avec le PAT `sbp_...` → `POST https://api.supabase.com/v1/projects/<ref>/database/query` body `{"query":"..."}`. Le classifieur bloque les mutations d'auth (mots de passe) sans feu vert explicite. Voir [[supabase-credentials]] [[verifier-base-live-vs-schema]].
