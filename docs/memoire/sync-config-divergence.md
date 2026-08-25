---
name: sync-config-divergence
description: "Déploiement sync-rules PowerSync : le Cloud LIVE utilise bucket_definitions (= config/sync-rules.yaml) ; sync-config.yaml (streams éd.3) est MORT ; commande de deploy CLI exacte"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9b4ef359-e046-4e8e-b7b4-1eba29609363
---

✅ **RÉSOLU 2026-06-28 (via `fetch config` sur l'instance live).** La « divergence » alarmante n'en était pas une — voici la vérité opérationnelle du déploiement PowerSync :

**Le Cloud LIVE utilise le format `bucket_definitions`** (PAS streams). L'instance Cloud **« Development »** `6a185941234fa2bf51a66757` (= `cli.yaml`, = `_powerSyncUrl` dans `powersync_connector.dart` → l'app s'y connecte) a ses `syncRules` en `bucket_definitions`, et leur contenu **= `powersync/config/sync-rules.yaml` à l'octet près**. Donc CLAUDE.md a raison : `config/sync-rules.yaml` EST la source de vérité, et les déploiements EDT/Matières/struct précédents ont bien atterri.

**`powersync/sync-config.yaml` (format streams, `config: edition: 3`) est MORT** — un commentaire dans la config live le dit : l'édition 3 utilisait des JOIN → AUCUNE donnée ne synchronisait → abandonné, retour aux `bucket_definitions`. **Ignorer `sync-config.yaml`** ; ne jamais le déployer (il manque ~20 tables et régresserait la prod).

**Commande de déploiement (validée, additive, sûre)** — depuis la racine `/home/melack/E-PILOTE`, avec `PS_ADMIN_TOKEN` exporté (PAT `jpt_…` fourni par le user) :
```
npx --no-install powersync deploy sync-config \
  --directory=powersync \
  --sync-config-file-path=/home/melack/E-PILOTE/powersync/config/sync-rules.yaml
```
Le flag `--sync-config-file-path` force le CLI à pousser le BON fichier (bucket_definitions) au lieu de `sync-config.yaml`. ⚠️ Le **deploy poll jusqu'à 300 s** ; l'outil Bash coupe à 120 s mais **le deploy continue côté serveur** — vérifier APRÈS avec `npx --no-install powersync fetch config --output yaml` (LECTURE SEULE, n'écrase rien) puis grep la table.

**Méthode de pré-vérif d'un deploy** (toujours, avant prod nationale) : `fetch config` → extraire le bloc `syncRules` → `diff` la liste `FROM <table>` vs `config/sync-rules.yaml` ; n'accepter que des AJOUTS (jamais de table en moins). Le 2026-06-28, deploy de `school_holidays` = +1 table, 0 retrait → OK.

**Instances** : « Development » (provisioned ✅, = celle de l'app) et « Production » `6a185943234fa2bf51a66759` (has_config mais **is_provisioned: false** → pas encore active). ⚠️ `powersync pull instance` ÉCRASE `service.yaml`+`sync-config.yaml` locaux. Voir [[powersync-status]], [[enseignement-emploi-du-temps]].
