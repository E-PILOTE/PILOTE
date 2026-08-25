# Phase 2 — Réinitialisation du code PIN de poste par admin_groupe

**Date** : 2026-07-06
**Statut** : à valider
**Dépend de** : Phase 1 (`2026-07-06-poste-partage-vitrine-securite-design.md`) — déjà livrée (`agent_pin_set_at` en place).
**Sensibilité** : ⚠️ touche migration + sync-rules (déploiement dashboard PowerSync).

## Problème

Le code PIN d'un agent est **haché en local** (`SharedPreferences`) sur le poste de l'école, jamais synchronisé. Si un agent l'oublie, personne ne peut le réinitialiser à distance — or admin_groupe est *online* (`supabase.from()`), sur une autre machine, sans accès au stockage local du poste.

## Principe (offline-first, validé au brainstorming)

Admin_groupe **pose un drapeau serveur** ; le poste l'**honore hors-ligne** :

1. Admin_groupe (écran Utilisateurs) → « Réinitialiser le code du poste » → `profiles.pin_reset_requested_at = now()`.
2. Le drapeau **redescend par PowerSync** (bucket `directory`) sur les postes de l'école.
3. Le poste compare le drapeau à la **date locale de création du PIN** (`agent_pin_set_at`, Phase 1). Si `reset > set` → le PIN local est considéré **absent** → l'agent doit en **recréer un**.
4. À la recréation, `agent_pin_set_at = now()` > drapeau → PIN de nouveau valide (**auto-réparateur**, aucun nettoyage du drapeau requis).

Le reset invalide le PIN de cet agent sur **tous les postes** de son école (comportement voulu : « j'ai oublié mon code »).

## Changements

### 1. Base — migration `0033_agent_pin_reset.sql`
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin_reset_requested_at timestamptz;
COMMENT ON COLUMN profiles.pin_reset_requested_at IS
  'Horodatage d''une demande de reset du PIN de poste (admin_groupe). Le poste
   invalide le PIN local si ce champ est postérieur à sa date de création locale.';
```
- **RLS** : AUCUNE nouvelle policy — la policy UPDATE existante d'admin_groupe sur `profiles` (row-level : `group_id = auth_group_id() AND is_admin_groupe()`) couvre déjà la colonne. ⚠️ **Vérifier live** avant : (a) la colonne n'existe pas encore, (b) la policy UPDATE admin_groupe sur `profiles` est bien présente (le code `admin_users_provider` l'utilise déjà → attendu OK).

### 2. Sync-rules (`config/sync-rules.yaml`)
Ajouter `pin_reset_requested_at` à la liste de colonnes du bucket **`directory`** (seule source de `profiles`) :
```yaml
      - SELECT id, group_id, school_id, role, access_profile_id,
          first_name, last_name, phone, avatar_url, employee_number,
          date_of_birth, is_active, last_login, created_at, updated_at,
          pin_reset_requested_at
        FROM profiles
        WHERE school_id = bucket.sid AND is_active = true
```
⚠️ Redéploiement via **dashboard PowerSync** (pré-vérif `fetch config`). Voir [[sync-config-divergence]].

### 3. Schéma local (`powersync_schema.dart`)
Ajouter à la table `profiles` : `Column.text('pin_reset_requested_at')`.

### 4. Client — réconciliation (`active_agent_provider.dart`)
- `switchableAgentsProvider` : ajouter `pin_reset_requested_at` au SELECT ; `AgentOption.pinResetRequestedAt` (DateTime?).
- **Fonction pure testable** :
```dart
bool pinResetInvalidates(DateTime? resetAt, DateTime? setAt) =>
    resetAt != null && (setAt == null || resetAt.isAfter(setAt));
```
- `agent_lock_screen._pick` : `isCreate` devient
  `!(await hasPin(id)) || pinResetInvalidates(agent.pinResetRequestedAt, await pinSetAt(id))`.
  Si invalidé → aussi `clearFails(id)` (un reset lève le cooldown éventuel).

### 5. Admin_groupe — action UI
- `AdminUsersNotifier.resetAgentPin(String id)` (calqué sur `setActive`) :
  `update({'pin_reset_requested_at': now, 'updated_at': now}).eq('id', id)` + invalidate.
- Bouton « Réinitialiser le code du poste » dans le détail/menu utilisateur (personnel scolaire uniquement — pas super_admin/admin_groupe/parent/élève), avec **dialogue de confirmation** expliquant que l'agent devra recréer son code.

### 6. Tests
- `pinResetInvalidates` : matrice (resetNull / setNull / reset>set / reset<set / égaux).
- `AgentPinService` : après un reset simulé (`pinSetAt` < resetAt), `_pick` force la création (test flux widget avec `pin_reset_requested_at` injecté dans l'agent).
- `resetAgentPin` : provider écrit bien la colonne (mock client).

## Ordre de déploiement (sûr, incrémental)
1. Appliquer migration 0033 (colonne nullable — 0 risque).
2. Déployer sync-rules (colonne alors synchronisée ; app actuelle l'ignore).
3. Publier l'app (client honore le drapeau).
4. Le bouton admin_groupe devient utile.
Chaque étape est rétro-compatible : tant que l'app ne lit pas la colonne, `null` = aucun effet.

## Hors périmètre
- Reset en libre-service sur le poste (casserait la responsabilité d'attribution — écarté en Phase 1).
- Notification à l'agent (pourrait venir via le centre de notifications, plus tard).
