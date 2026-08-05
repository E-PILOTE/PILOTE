---
name: powersync-deploiement-cli
description: "🚀 Les sync-rules se déploient en ligne de commande (`npx powersync deploy sync-config`) — plus besoin du dashboard ; ⚠️ l'app pointe sur l'instance DEVELOPMENT, la PRODUCTION n'est pas provisionnée"
metadata: 
  node_type: memory
  type: reference
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T14:21:31.396Z
---

# Déployer les sync-rules sans le dashboard (2026-08-04)

La CLI officielle `powersync` (npm, v0.10.0) déploie la configuration de
synchro. Le dashboard n'est plus un passage obligé.

```bash
npm i powersync                      # dans un dossier de travail jetable
export PS_ADMIN_TOKEN='jpt_…'        # PAT PowerSync — JAMAIS sur disque
npx powersync fetch instances        # topologie org/projet/instances
mkdir -p psdeploy && cd psdeploy
npx powersync pull instance --instance-id <id>   # écrit powersync/sync-config.yaml (le LIVE)
# → comparer le LIVE au dépôt AVANT de toucher quoi que ce soit :
diff <(grep -vE '^\s*#|^\s*$' powersync/sync-config.yaml) \
     <(grep -vE '^\s*#|^\s*$' ~/E-PILOTE/powersync/config/sync-rules.yaml)
cp ~/E-PILOTE/powersync/config/sync-rules.yaml powersync/sync-config.yaml
npx powersync validate               # schéma + connexions + sync config
npx powersync deploy sync-config     # ⚠️ sync-config SEUL, pas les connexions
npx powersync status                 # « Initial replication done », lag 0
```

`pull instance` garde une copie du live : **c'est le retour arrière**.

## ⚠️ Topologie réelle (à savoir avant le 2 octobre)

```
Organisation E-PILOTE (6a1858e9ec3f4400078f635f)
└── Projet EPILOTE (6a18593de63d960007e81e7b)
    ├── Development  6a185941234fa2bf51a66757  provisionnée ✅
    └── Production   6a185943234fa2bf51a66759  provisionnée ✅  ← l'APP POINTE ICI
```

✅ **Réglé le 2026-08-04.** Production a été provisionnée avec la config
exacte de Development, puis `_powerSyncUrl` (`powersync_connector.dart` —
et non `powersync_service.dart`) est passé sur elle, surchargeable par
`--dart-define=POWERSYNC_URL=…` pour la recette.

⚠️ Provisionner exige les secrets, qui sont des `secret_ref` par instance
donc NON copiables. Les fournir en clair est refusé par le garde-fou de
session : passer par `secret: !env VAR` dans `service.yaml` (la forme
attendue est une MAP, pas une chaîne) et `set -a && . powersync/.env`.
Vérifier les secrets AVANT : le `SUPABASE_JWT_SECRET` doit signer la clé
anon de l'app (HMAC-SHA256 sur `header.payload`), et le mot de passe
`powersync_role` doit ouvrir une connexion à `db.<projet>.supabase.co`.

Après provisionnement : attendre `Initial replication done: true` avant de
basculer l'app — sinon le poste synchronise un corpus incomplet.
Une bascule d'instance fait RETÉLÉCHARGER les buckets (les données sont les
mêmes, l'état des buckets non). Deux instances provisionnées = deux
emplacements de réplication et deux instances facturées : décider si
Development doit être arrêtée (`powersync stop`, réversible par redeploy).

## Le jeton

PAT `jpt_…` = base64 de `{i: id, n: secret, u: user}`. Passer par
`PS_ADMIN_TOKEN` (jamais `powersync login`, qui l'écrit sur disque).
Un PAT collé dans une conversation est **à révoquer** ensuite.

Liens : [[sync-config-divergence]] · [[statut-emploi-personnel]] ·
[[powersync-status]]
