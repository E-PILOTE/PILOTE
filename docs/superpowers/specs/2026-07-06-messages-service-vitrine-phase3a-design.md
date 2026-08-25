# Phase 3a — Messages de service sur la vitrine des postes

**Date** : 2026-07-06
**Statut** : décidé (implémentation autonome)
**Dépend de** : Phase 1 (`VitrineShell` accepte déjà `serviceMessages`).
**Sensibilité** : ⚠️ migration + sync-rules (nouveau contenu dans le bucket global `global_catalog`).

## Décision de périmètre
Phase 3 est scindée : **3a = messages de service** (canal éditorial institutionnel, sain, faible risque) — implémenté ici. **3b = placements partenaires** — DIFFÉRÉ (spec séparée) : la curation partenaire (approbation, opt-in par groupe, stockage logos) engage une **politique** en contexte public/scolaire qui mérite l'arbitrage du responsable ; risque réputationnel signalé.

## But
Le super_admin diffuse de courts messages institutionnels (nouveautés, maintenance, annonces ministérielles) qui s'affichent dans la **vitrine au repos** de chaque poste partagé (carrousel lent, déjà câblé dans `VitrineShell`), y compris **hors-ligne** (via PowerSync).

## Changements

### 1. Base — migration `0034_platform_service_messages.sql`
```sql
CREATE TABLE IF NOT EXISTS platform_service_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  body        text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  starts_at   timestamptz,   -- visible à partir de (null = tout de suite)
  ends_at     timestamptz,   -- visible jusqu'à (null = sans fin)
  created_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE platform_service_messages ENABLE ROW LEVEL SECURITY;
-- super_admin : gestion complète (CRUD online).
CREATE POLICY psm_super_all ON platform_service_messages
  FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
-- lecture des messages actifs par tout authentifié (préversion admin_groupe ;
-- le staff, lui, les reçoit par sync — les sync-rules ne passent pas par la RLS).
CREATE POLICY psm_read_active ON platform_service_messages
  FOR SELECT USING (is_active = true);
```

### 2. Sync-rules (`config/sync-rules.yaml`) — bucket global `global_catalog`
```yaml
      - SELECT id, body, is_active, starts_at, ends_at
          FROM platform_service_messages WHERE is_active = true
```
Global = synchronisé à **tous les postes** (volume minuscule). ⚠️ Redéploiement dashboard PowerSync.

### 3. Schéma local (`powersync_schema.dart`)
Table `platform_service_messages` (id, body, is_active, starts_at, ends_at).

### 4. Staff — provider offline (`vitrine_messages_provider.dart`)
- **Fonction pure** `isMessageLive(DateTime now, DateTime? starts, DateTime? ends, bool active)`.
- `serviceMessagesProvider = StreamProvider<List<String>>` : `db.watch` sur `platform_service_messages`, filtré `is_active` + fenêtre de dates (client), triés `created_at` desc, plafonné à 3 → `List<String>` (corps).
- `AgentLockScreen` lit ce provider et le passe à `VitrineShell.serviceMessages`.

### 5. super_admin — CRUD online
- `platform_service_messages_provider.dart` : `FutureProvider` (liste via `supabase.from`) + `create/update/delete/toggleActive` (calqués sur `payment_methods_provider`).
- `platform_service_messages_screen.dart` : liste + formulaire (corps, actif, fenêtre de dates optionnelle) + toggle + suppression, style `AppShell`/`AdminCard`.
- Route `superMessagesAccueil = '/super/messagerie/accueil'` (+ router + entrée de nav section Messagerie).

### 6. Tests
- `isMessageLive` : matrice (actif/inactif × avant starts × après ends × dans la fenêtre × bornes nulles).
- Provider staff : mapping/tri/plafond 3 (via db mock ou test de la fonction de projection pure extraite).

## Ordre de déploiement (rétro-compatible)
1. Migration 0034. 2. sync-rules dashboard. 3. release app. 4. super_admin crée des messages.
Tant que la table est vide, la vitrine n'affiche aucun bandeau (comportement Phase 1 inchangé).

## Hors périmètre (Phase 3b, différée)
Placements partenaires : table `platform_partners` + opt-in par groupe + stockage logos + `VitrineShell.showPartner`. Spec dédiée à valider (politique de curation).
