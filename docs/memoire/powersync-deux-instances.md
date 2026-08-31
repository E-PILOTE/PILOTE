---
name: powersync-deux-instances
description: "⚠️ DEUX instances PowerSync : le parc utilise `…a66759` (Production), pas `…a66757` (Development) que citent toutes les vieilles notes. Déployer au mauvais endroit ne touche personne."
metadata: 
  node_type: memory
  type: project
---

**Établi le 2026-08-31, jeton d'administration en main.**

```
Organisation E-PILOTE / Projet EPILOTE
  Development  6a185941234fa2bf51a66757   provisionnée
  Production   6a185943234fa2bf51a66759   provisionnée
```

## ⚠️ Le piège

**Toutes les notes antérieures nomment `6a185941…757`** — [[powersync-status]],
[[espace-ecole-coquille]], [[modules-acces-hierarchie]], [[edt-refonte-v2]],
[[staff-support-offline]], [[sync-rules-data-protection]] — et disent « à
redéployer au dashboard ». **C'est l'instance Development.**

Depuis le **2026-08-04**, `lib/services/powersync/powersync_connector.dart`
pointe par défaut sur **`kPowerSyncProduction` = `…a66759`**. Déployer sur
`…757` ne change donc **rien pour le parc** — et le déploiement réussit, ce qui
donne toutes les apparences du succès.

La bascule est surchargeable au build :
`flutter build windows --dart-define=POWERSYNC_URL=$kPowerSyncDevelopment`.

## État constaté le 2026-08-31 (comparaison YAML normalisée, bucket par bucket)

| instance | écarts avec `config/sync-rules.yaml` |
|---|---|
| **Production** `…759` | **0** — déjà à jour, y compris `access_profiles` et `profile_permissions` |
| **Development** `…757` | en retard : `issued_documents`, `staff_photo_requests`, `bulletin_subject_lines` par école, le retrait du filtre `is_active` sur `students`, la séparation groupe/école de `academic_years`/`sequences`/`trimesters` |

→ **Development déployé et revérifié : 0 écart.** Production **non redéployée**,
délibérément : le contenu était identique après normalisation, et un déploiement
inutile relance le service et fait resynchroniser les postes pour rien.

⚠️ **Le correctif « espace école coquille » est donc DÉJÀ en production.** La
note qui l'annonce comme en attente parlait de Development.

## Comment refaire la comparaison sans rien déployer

```bash
cd powersync
export PS_ADMIN_TOKEN=…                    # jamais dans un fichier du dépôt
npx --yes powersync fetch instances
npx --yes powersync fetch config --instance-id=<id> --directory=. > /tmp/deploye.yaml
```
Puis comparer `deploye.yaml → syncRules` au fichier local **après normalisation
des espaces** : le service reformate le YAML (`>-` déplié), ce qui fait
apparaître 8 buckets « différents » qui sont en réalité identiques. Comparer les
chaînes brutes conduirait à redéployer la production sans raison.

## Déployer, quand c'est vraiment nécessaire

```bash
npx --yes powersync deploy sync-config --instance-id=<id> \
    --directory=. --sync-config-file-path config/sync-rules.yaml
```

⚠️ **`--sync-config-file-path` est OBLIGATOIRE** : `powersync/sync-config.yaml`
existe encore, date du 2026-06-10 et est **périmé**. Sans le drapeau, c'est lui
que la CLI déploierait.

⚠️ `validate` échoue sur `service.yaml` (absent du dépôt : la connexion est
configurée côté Cloud). Seul `✓ Validate Sync Config` compte ; `deploy
sync-config` ne lance que celle-là.

Voir [[powersync-status]] · [[mise-a-jour-du-parc]]
