---
name: foundation-schema-audit
description: "Audit fondation offline (55 tables) : schéma local↔live↔sync-rules ; fondation saine, 1 bug actif corrigé (announcements.is_archived) + 1 dormant (staff_members.profile_id)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

✅ 2026-06-21 — **Étape 1 de la stratégie « hybride borné »** (valider la fondation AVANT les modules en profondeur, cf [[staff-personnel-annuaire]]). Audit systématique des **55 tables synchronisées / 669 colonnes**.

**Méthodo (reproductible) :** extraire les paires `table|colonne` de `powersync_schema.dart` (perl) → diff contre `information_schema.columns` live (psql pooler `aws-1-eu-central-2`) dans les 2 sens → croiser avec `sync-rules.yaml`. Écart **dangereux** = colonne déclarée LOCAL mais absente PROD (écriture offline → échec upload silencieux). Écart **info** = colonne PROD non synchronisée (souvent volontaire).

**VERDICT : fondation offline SAINE.** Sur 55 tables, **2 écarts seulement**, et **toutes les tables locales sont couvertes par les sync-rules** (aucune orpheline).

1. **`announcements.is_archived`** (live-only mais UTILISÉ offline) = **BUG ACTIF corrigé** (commit `67fcf6d`). `setAnnouncementArchivedLocal` fait `db.execute('UPDATE announcements SET is_archived…')` → sans la colonne au schéma local = « no such column » au 1er archivage hors-ligne. Fix = `Column.integer('is_archived')` ajouté ; sync-rules font déjà `SELECT * FROM announcements` → **aucun redéploiement règles requis**.

2. **`staff_members.profile_id`** (local-only, absent prod) = **dormant, LAISSÉ tel quel.** `myStaffIdProvider` (`permissions_provider.dart:121`) le LIT (`SELECT id FROM staff_members WHERE profile_id=?`) → renvoie toujours null (jamais peuplé), **inoffensif**. Le RETIRER ferait crasher cette requête. Aucune écriture offline dessus. Commentaire d'avertissement posé. À matérialiser en **Phase 5 (Paie)** : ALTER TABLE prod + FK + aligner schéma local. Cf [[staff-personnel-annuaire]], [[profil-source-de-verite-droits]].

**Autres live-only = volontaires/online-only (vérifié, AUCUN en SQL offline) :** `payment_configs.api_key/api_secret` + `staff_members.iban` (sensibles exclus) ; `schools.latitude/longitude/location_*/capacity/parent_portal_enabled` + `school_groups.founded_year/created_by` (admin_groupe/super_admin online — `schools.capacity` ≠ dashboard école qui calcule le remplissage depuis `classes.capacity`) ; `profiles.address/birth_place/gender/sync_finance/sync_medical/sync_discipline` (sync_* = drapeaux RLS serveur, gating offline via profile_permissions). `parent_portal_enabled` à synchroniser quand on bâtira l'espace Parent.

**Conséquence roadmap :** la couche offline est validée → on peut enchaîner les modules en profondeur sans craindre des écarts schéma cachés. Refaire ce diff après toute migration prod.
