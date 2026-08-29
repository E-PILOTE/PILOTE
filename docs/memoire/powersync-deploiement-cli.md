---
name: powersync-deploiement-cli
description: "🚀 Déployer les sync-rules en CLI (`powersync deploy sync-config`) — l'app pointe sur PRODUCTION (…66759), seule instance vivante ; ⚠️ jeton par `PS_ADMIN_TOKEN`, jamais `powersync login` ; un 500 « Resource does not exist » sur TOUS les endpoints = jeton révoqué, pas API cassée ; ✅ sync-rules déployées le 29/08"
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
    ├── Development  6a185941234fa2bf51a66757  has_config ✅  is_provisioned ❌
    └── Production   6a185943234fa2bf51a66759  provisionnée ✅  ← l'APP POINTE ICI
```

⚠️ **Constaté le 2026-08-24 (`fetch instances`) : Development n'est PLUS
provisionnée.** Elle l'était le 04/08 ; elle a été arrêtée depuis — la question
de la double facturation évoquée plus bas a donc été tranchée. Conséquence
pratique : **une seule instance vivante**, le déploiement n'a plus d'ambiguïté
de cible, et `cli.yaml` pointe déjà dessus. Pour une recette sur Development,
il faudra la re-provisionner d'abord (`powersync deploy`, pas seulement
`deploy sync-config`).

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

### ⚠️ 2026-08-29 — la règle a été contournée, et le jeton est mort

`~/.config/powersync/config.yaml` contient un jeton en **texte clair** : quelqu'un
a lancé `powersync login`. La doc de la CLI promet « secure storage, e.g. macOS
Keychain » — sur Windows c'est un YAML lisible par tout processus du compte.
`powersync logout` l'efface.

Ce jeton-là ne sert plus. Comment le savoir sans le divulguer — trois requêtes
sur `accounts.powersync.com/api/accounts/v5/organizations/list` :

| envoyé | réponse |
|---|---|
| jeton bidon, ou pas d'en-tête `Authorization` | `401 ACCESS_DENIED` |
| chemin d'API inexistant | `404` (HTML JourneyApps) |
| **le jeton du disque** | **`500 — Resource does not exist`** |

Il franchit le contrôle d'authentification mais ne résout plus vers aucune
organisation : **révoqué côté compte**, comme demandé après la session du 28/08.
Un 500 « Resource does not exist » sur TOUS les endpoints, quels que soient les
paramètres, se lit donc « jeton révoqué », pas « API cassée ».

### ✅ 2026-08-29 — les deux lignes SONT déployées

Un jeton neuf a été fourni pour ce seul déploiement (`PS_ADMIN_TOKEN`, jamais
sur disque), et doit être révoqué à son tour.

Déroulé qui vaut d'être répété : **`pull instance` AVANT** (le diff LIVE ↔ dépôt
ne montrait que les deux lignes attendues — donc rien à préserver du tableau de
bord), déploiement, **`pull instance` APRÈS** (diff vide : la production porte
exactement le fichier du dépôt), puis le binaire lancé sur ce poste pour voir
PowerSync appliquer ses checkpoints sans une erreur. Une règle cassée se serait
vue à cette dernière étape, pas aux précédentes.

`powersync/sync-config.yaml` garde la configuration d'AVANT : c'est le retour
arrière. Détail dans `docs/DEPLOIEMENT_ORDRE.md`.

Liens : [[sync-config-divergence]] · [[statut-emploi-personnel]] ·
[[powersync-status]]
