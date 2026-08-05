# Reprendre E-PILOTE sur un nouveau poste (Windows 11 Pro)

Écrit le 5 août 2026, au moment de changer de machine. Ce fichier dit ce que
GitHub rapporte, **ce qu'il ne rapporte pas**, et dans quel ordre remonter.

---

## 1. Ce que GitHub NE rapporte PAS

Ces éléments sont volontairement gitignorés. Ils doivent voyager **autrement**
(clé USB, gestionnaire de mots de passe) — pas par le dépôt, même privé.

| Chemin | Contenu | Comment le récupérer |
|---|---|---|
| `powersync/.env` | `SUPABASE_DB_PASSWORD`, `SUPABASE_JWT_SECRET`, `STORAGE_DB_PASSWORD` | recopier depuis l'ancien poste ; gabarit dans `powersync/.env.example` |
| `powersync/cli.yaml` | identifiants d'instance PowerSync Cloud | recopier ; **`instance_id` doit valoir `6a185943234fa2bf51a66759` (Production)** |
| `backups/` | 9,2 Mo de CSV — **données scolaires réelles** (élèves, personnels, paiements) | clé USB. Ne jamais committer. |
| `.claude/`, `.remember/` | mémoire projet et historique de session | clé USB si l'on veut garder le contexte |
| `epilote/.env` | clés Supabase locales | gabarit dans `epilote/.env.example` |

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
