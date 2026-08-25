# Reprendre E-PILOTE sur un nouveau poste (Windows 11 Pro)

Écrit le 5 août 2026, au moment de changer de machine. Ce fichier dit ce que
GitHub rapporte, **ce qu'il ne rapporte pas**, et dans quel ordre remonter.

---

## 1. Ce que GitHub NE rapporte PAS

Ces éléments sont volontairement gitignorés. Ils doivent voyager **autrement**
(clé USB, gestionnaire de mots de passe) — pas par le dépôt, même privé.

### La mémoire du projet, elle, EST dans le dépôt

Les 121 fiches de contexte (décisions gelées, pièges déjà payés, état réel de
la base) sont désormais versionnées dans **`docs/memoire/`** — voir le
`README.md` de ce dossier pour les remettre en service. C'était le seul élément
dont la perte aurait vraiment coûté quelque chose.

### Ce qui ne peut pas suivre

| Chemin | Contenu | Comment le récupérer |
|---|---|---|
| `powersync/.env` | trois clés, dont **une seule** est un vrai secret — voir §2 bis | gestionnaire de mots de passe |
| `backups/` | 9,2 Mo de CSV — **données personnelles réelles** (élèves mineurs, personnels, paiements) | clé USB. Jamais dans un dépôt : un historique git ne s'efface pas. |
| `.remember/` | journal de sessions brut (3,4 Mo) | inutile — son contenu utile est distillé dans `docs/memoire/` et l'historique git |

`powersync/cli.yaml` **est maintenant versionné** : il ne portait que des
identifiants d'instance, déjà en clair dans `powersync_connector.dart`.

## 2 bis. Reconstituer `powersync/.env` — une seule valeur à transporter

```bash
cp powersync/.env.example powersync/.env
```

| Clé | Où la reprendre |
|---|---|
| `STORAGE_DB_PASSWORD` | **rien à faire** : c'est la valeur par défaut du gabarit (base PostgreSQL locale du conteneur, sans enjeu) |
| `SUPABASE_JWT_SECRET` | **se relit** au dashboard : Supabase → Settings → API → JWT Settings |
| `SUPABASE_DB_PASSWORD` | mot de passe du rôle `powersync_role`. **Le seul à transporter** — gestionnaire de mots de passe. Perdu, il se réinitialise : `ALTER ROLE powersync_role WITH PASSWORD '…';` puis mettre la nouvelle valeur dans la connexion du dashboard PowerSync, sinon la réplication s'arrête. |

⚠️ **Le jeton PowerSync (PAT) collé dans une session précédente est à
considérer comme compromis.** Ne pas le réutiliser sur le nouveau poste : en
générer un neuf depuis le dashboard PowerSync et révoquer l'ancien.

---

## 2. Installer la chaîne de développement

```powershell
# Flutter (canal stable) — puis vérifier
flutter --version
flutter doctor

# Visual Studio 2022 avec la charge « Développement Desktop en C++ »
# (obligatoire pour `flutter build windows`)

# Git + GitHub CLI
gh auth login          # compte E-PILOTE
```

⚠️ **CMake ≥ 3.15 et `audioplayers` ≥ 6.8.1** sont obligatoires pour que la
compilation Windows aboutisse (cf. `[[chaine-livraison-windows]]`).

Sous Windows, `libsecret` n'existe pas : `flutter_secure_storage` bascule sur
le coffre système. Rien à installer — c'est la contrainte Linux qui disparaît.

---

## 3. Récupérer le dépôt

```powershell
git clone https://github.com/E-PILOTE/PILOTE.git E-PILOTE
cd E-PILOTE
git checkout feat/livraison-windows
cd epilote
flutter pub get
flutter analyze          # doit rendre 0 issue
flutter test             # 934 tests attendus
flutter run -d windows
```

---

## 4. Vérifier que la base est bien à jour

L'état de référence est la base Supabase **live**, pas les fichiers du dépôt.
`database/schema.sql` et `docs/CONTEXTE.md` sont périmés — ne pas s'y fier.

Dernière migration appliquée en production : **0096**
(`0096_le_bareme_appartient_au_groupe.sql`).

```powershell
$env:PGPASSWORD="<mot de passe postgres>"
psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 `
     -U postgres.wqpdamlnrwgozfvzjjpo -d postgres `
     -c "select is_nullable from information_schema.columns
         where table_name='fee_structures' and column_name='school_id';"
```

Attendu : `YES`. Si c'est `NO`, la 0096 n'est pas passée.

---

## 5. ⚠️ Le seul chantier resté ouvert : déployer les sync-rules

`powersync/config/sync-rules.yaml` a été modifié (le bucket `by_group` projette
désormais les barèmes de portée réseau) **mais le déploiement n'a pas pu être
fait** : la CLI n'était pas authentifiée.

Tant que ce déploiement n'est pas passé, un tarif publié par le ministère
**pour tout le réseau** reste invisible sur les postes des écoles. Un tarif
publié **pour une école précise** descend normalement (bucket `by_school`, déjà
déployé) — c'est ce qui a servi à la recette.

```powershell
cd E-PILOTE
npx --yes powersync@latest login      # jeton NEUF, pas l'ancien
npx --yes powersync@latest deploy sync-config
```

Vérifier ensuite qu'un tarif « Tout le réseau » créé depuis l'espace ministère
apparaît bien dans Finance ▸ Frais de scolarité d'une école.

---

## 6. Ce qui reste au programme

- **Finance lot 2b** : versement sur obligation (barème obligatoire à
  l'encaissement, avance explicite), exonérations, écran de préparation
  « niveaux et types de frais sans tarif », circuit « demander un tarif ».
- **Finance lot 3** : tarif figé sur l'encaissement, alerte de dépassement sur
  le CUMUL, écran « Écarts au tarif officiel ».
- **Recetter le binaire Windows sur un vrai poste** — personne n'a jamais lancé
  le `.exe`. C'est le plus gros risque non levé du déploiement du 2 octobre, et
  le nouveau poste est justement l'occasion de le faire.
- Le **budget de fonctionnement** porte le même défaut que les barèmes
  (l'école se vote son budget). Hors périmètre tant que ce n'est pas rouvert.
