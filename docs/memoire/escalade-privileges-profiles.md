---
name: escalade-privileges-profiles
description: "⛔ CRITIQUE — un compte enseignant pouvait s'écrire role='super_admin' sur sa propre ligne profiles et prendre toute la plateforme ; fermé par 0125 (déclencheur qui RAMÈNE les colonnes de pouvoir)"
metadata:
  node_type: memory
  type: project
---

# ⛔ L'ESCALADE DE PRIVILÈGES (trouvée et fermée le 2026-08-27)

**Le défaut le plus grave de tout l'audit.** Il ne vivait dans aucun module :
il vivait dans la table qui PORTE les droits.

## Le mécanisme

`profiles_update` autorise un membre à mettre à jour SA propre ligne
(`id = auth.uid()`), et son `WITH CHECK` était **NUL** — Postgres retombe alors
sur le `USING`, qui reste vrai puisque c'est toujours sa ligne. **Aucune colonne
n'était protégée.** Or tout le contrôle d'accès de la plateforme se lit dans
cette table :

```
is_super_admin()  = profiles.role = 'super_admin'
is_admin_groupe() = profiles.role = 'admin_groupe'
auth_school_id()  = profiles.school_id
auth_group_id()   = profiles.group_id
les 4 verrous     = profiles.access_profile_id
```

Mesuré en production avec un compte **enseignant**, transaction annulée :

```
AVANT  role=enseignant  finance=f
  se donner le profil DIRECTION      : OUI
  se déclarer SUPER_ADMIN            : OUI     ← toute la plateforme
  se transférer dans une AUTRE école : OUI
APRÈS  role=super_admin  finance=t
```

Et le déclencheur `profiles_sensitive_flags` — qui DÉRIVE `sync_finance` /
`sync_medical` / `sync_discipline` du profil d'accès — **achevait le travail** :
il ouvrait de lui-même la paie, le médical et la discipline. Un garde-fou
retourné en amplificateur.

## La parade — 0125

Déclencheur `aa_profiles_garde_pouvoir` (BEFORE UPDATE). Un membre garde le
droit de corriger son état civil ; les colonnes de pouvoir (`role`,
`access_profile_id`, `school_id`, `group_id`, `is_active`, `sync_*`) sont
**RAMENÉES** à leur valeur d'origine.

**Ramenées, pas refusées** — et c'est le point de conception : un refus lèverait
42501, code FATAL pour le connecteur PowerSync, qui jette le LOT ENTIER en
attente. L'appareil remonte ses lignes en `upsert` complet : un poste dont la
copie locale de `profiles` a vieilli renverrait un `role` périmé sans aucune
intention de nuire, et perdrait au passage les notes et les paiements du même
lot. On neutralise l'écriture au lieu de l'interdire.

⚠️ Le préfixe `aa_` n'est pas décoratif : Postgres exécute les déclencheurs de
même moment par ORDRE ALPHABÉTIQUE, et celui-ci doit passer avant
`profiles_sensitive_flags`.

⚠️ `auth.uid()` nul ⇒ on ne touche à rien (migrations, Edge Functions en
`service_role`).

Vérifié après : la requête d'escalade **passe** (1 ligne, donc aucun 42501,
aucun lot jeté) mais ne change rien ; le prénom du même UPDATE, lui, change ; et
l'admin groupe administre toujours.

## 📐 Ce que ce défaut apprend sur la forme de la base

Relevé du 2026-08-27 sur les tables portant `school_id` :

- **3 familles de gardes** coexistent : `auth_module_permet` (verrou 3 par
  module, posé par 0114/0118/0121/0123), `auth_sync_*` (drapeaux
  médical/finance/discipline dérivés du profil), et **rien du tout**.
- **52 tables** n'ont ni l'un ni l'autre : une seule politique `FOR ALL` qui ne
  vérifie que l'appartenance à l'école.

Les plus lourdes, par volume réel : `students` (9 106), `class_enrollments`
(9 106), `class_subjects` (3 904 — les coefficients, donc les moyennes),
`exam_candidates` (2 126), `classes` (494), `audit_logs` (82),
`exam_official_results` (14).

⚠️ **Ne PAS les gâter en bloc.** La leçon 0116 tient : un droit d'écriture se
déduit des ÉCRANS QUI ÉCRIVENT, pas du nom d'une table. C'est précisément ce
que produit l'audit module par module — chaque module apporte la liste de ses
écrans, donc la liste juste des modules à admettre.

## ✅ Ce qui a été refermé dans la foulée

- **0126 — `students` + `class_enrollments`** (9 106 lignes chacune). La liste
  des modules a été déduite des écrans qui écrivent : `class_enrollments` est
  écrite par **cinq** modules (`inscriptions`, `eleves`, `conseils`,
  `transferts`, `discipline` — l'exclusion pose `status='withdrawn'`).
  N'admettre que `inscriptions` aurait cassé la Vie scolaire qui exclut et
  l'enseignant qui pose une décision de passage — 42501, lot jeté.
  ⚠️ Résidu nommé : une politique porte sur la TABLE, pas sur la COLONNE.
- **0127 — `audit_logs` en lecture seule côté client.** Tout membre du
  personnel pouvait insérer de fausses traces et effacer les siennes. Aucune
  écriture client n'est légitime : le seul écrivain est un déclencheur
  `SECURITY DEFINER`, qui ne passe pas par RLS. Vérifié : insertion refusée,
  déclencheur intact (19 → 20 lignes).

## 🔎 Déjà protégées — ne pas y retoucher

`academic_years`, `trimesters`, `exam_official_results` ont déjà un
`*_write_ministry` réservé à admin_groupe. `fee_structures` a ses quatre
politiques. `infirmary_visits`, `discipline_incidents`, `payroll` sont gâtées
par les drapeaux `auth_sync_medical / _discipline / _finance`, dérivés du profil
d'accès par le déclencheur `profiles_sensitive_flags`.

## ✅ 0128 / 0129 — coefficients, classes, matières, candidats

- **`class_subjects` (3 904)** : le COEFFICIENT d'une matière dans une classe.
  Le changer change toutes les moyennes générales, donc tous les bulletins, les
  rangs et les mentions — silencieusement.
- **`exam_candidates` (2 126)** : retirer une inscription prive un enfant de son
  examen. **`classes` (494)**, **`subjects` (62)**.

⚠️ **Le Calendrier scolaire n'est PAS un module.** `school_calendar_screen`
n'utilise pas `ModuleScaffold` : écran natif gardé par le RÔLE
(`_kEditRoles = {proviseur, directeur}`). `auth_module_permet` ne peut pas le
couvrir — d'où le helper `auth_est_chef_etablissement()`. L'ignorer aurait cassé
la préparation de la rentrée par un 42501.

⚠️ **0129 corrige un choix de 0128 que la vérification a révélé** : admettre
`conseils` en écriture sur `classes`/`class_subjects` (à cause du rollover
lancé depuis passage_screen) laissait tout enseignant créer des classes et
réécrire des coefficients. Le bouton « Reconduire les classes » est désormais
réservé à `conseils.validate`, dans l'écran ET en base.

## ✅ 0130 — les pièces d'un enfant et sa famille

`student_documents` (actes de naissance, certificats, photos, pièces d'examen
et de stage) et `student_tutors` (parents et responsables : noms, téléphones,
liens de parenté, adresses) étaient en tenancy seule. Ce sont des données
personnelles de **mineurs et de tiers non employés par l'école**, et elles ne
relèvent d'aucun drapeau `auth_sync_*` : rien ne les protégeait.

**CINQ modules écrivent les pièces** (`documents`, `inscriptions`, `eleves`,
`examens`, `stages`), **TROIS les tuteurs** (`inscriptions`, `eleves`,
`annuaire`). Vérifié : Direction et Secrétariat oui, Enseignant et Vie scolaire
refusés.

## ⚖️ Ce qui relève de la CONFIGURATION, pas du code — à trancher

1. **Le profil « Enseignant » livré détient `matieres` et `classes` en
   create+update.** Un professeur peut donc changer un coefficient — celui qui
   fixe toutes les moyennes de la classe — et créer une classe. Ce n'est plus un
   défaut de RLS après 0129 : c'est un choix de profils d'accès.
2. **Qui fait l'appel** (cf. [[presences-appel-identite-deduite]]) : l'enseignant
   n'a aucun droit d'écriture sur les présences, alors que `ANALYSE.md` §7 en
   fait la raison d'être du hors-ligne.
3. **`directeur_etudes` n'est pas dans l'enum `user_role`.** Il figurait dans
   `AppConstants.directionRoles` : un test de rôle qui ne pouvait jamais
   réussir — le piège de `roleUtilisateur`, retiré le 2026-08-27. « Directeur
   des Études » existe comme PROFIL D'ACCÈS (`access_profiles.role_type`), pas
   comme rôle. La personne qui occupe ce poste reçoit donc un autre rôle, et si
   c'est `enseignant`, elle n'atteint pas le Calendrier scolaire malgré son
   profil. **Ajouter la valeur à l'enum, ou assumer qu'un D.E. porte
   `directeur` ?**

## ⏳ Restent ouvertes, par ordre de poids

Les grosses sont faites (0126, 0128, 0129). Le reste des 52 est presque
entièrement vide aujourd'hui : `staff_*`, `timetable_*`, `library_*`,
`canteen_*`, `internships`, `transmissions`, `rooms`, `lesson_entries`…
Chacune se traitera avec son module, quand l'audit y arrivera.

## 🚨 Deux trous nommés, non refermés

1. ~~**L'audit n'existe quasiment pas.** Un seul déclencheur dans toute la
   base.~~ ⚠️ **FAUX — mesuré le 2026-09-01.** Quinze tables sont
   instrumentées par cinq fonctions : notes, bulletins, paiements, paie,
   inscriptions, élèves, incidents, matières de classe, niveaux, tarifs et les
   trois tables d'EDT. Le journal enregistre bien, et précisément (seul le
   champ modifié, avec l'ancienne et la nouvelle valeur).
   Ce qui était vrai : il couvrait **un verbe sur deux** sur quatre tables —
   refermé par `0170`. Voir [[audit-module-partage-scope]].
2. **`/user/audit` viole la règle centrale** : l'écran d'audit partagé
   (`features/audit/providers/audit_data.dart`) lit par `SupabaseClient` +
   realtime, alors qu'il est routé dans l'espace PERSONNEL, qui doit être
   PowerSync uniquement. Hors ligne, cette page ne montre rien.

Voir [[evaluation-notes-bulletins]], [[presences-appel-identite-deduite]],
[[modules-acces-hierarchie]], [[sync-rules-data-protection]].

## 🩸 LE REMÈDE A CASSÉ LA CRÉATION DE COMPTES (2026-09-04 → 06, mig 0194)

**Pendant deux jours, plus aucun compte ne pouvait être créé** — sauf par un
super_admin — et **rien ne le disait**. Le formulaire affichait « Utilisateur
créé avec succès », le compte s'authentifiait auprès de Supabase, puis
l'application le rejetait. Deux comptes en sont morts (Ramsos MELACK le 04,
Grace MENGOBI le 06) ; trouvés parce que le fondateur n'arrivait pas à se
reconnecter avec un compte qu'il venait de créer, la veille de la présentation
au ministre.

### Le mécanisme

`create_school_user` procède en **deux instructions** :

1. `insert into auth.users` → le déclencheur `fn_handle_new_user` tire un
   profil des seules métadonnées : prénom, nom, rôle. **`group_id` et
   `school_id` y sont NULS** ;
2. `update profiles set group_id = …, school_id = …` — c'est CETTE
   instruction qui rattache la personne.

Le garde de la 0188 évalue, sur cet UPDATE :

```sql
IF v_admin_groupe AND OLD.group_id IS NOT DISTINCT FROM auth_group_id()
```

`OLD.group_id` vaut NULL — le profil vient d'être inséré vide.
**`NULL IS NOT DISTINCT FROM '<uuid>'` vaut FAUX.** Le bloc est sauté, on
tombe dans le repli, et `group_id` / `school_id` / `access_profile_id` sont
remis à NULL **au moment même où ils s'écrivent**. Prénom, nom et téléphone
passent — ils ne sont pas des colonnes de pouvoir — d'où un profil qui a l'air
complet et n'appartient à rien.

⚠️ **Le même défaut fermait `creer_agent_ecole`** : un chef d'établissement
n'est ni super_admin ni admin_groupe, il tombait droit dans le repli. **Les
deux seules portes de provisionnement du produit étaient closes.**

### Pourquoi c'est resté invisible

**Un déclencheur BEFORE qui réécrit `NEW` ne lève rien et ne journalise rien.**
L'UPDATE « réussit » — il écrit simplement autre chose que ce qu'on lui a
demandé. Même famille que les `catch (_) {}` : le silence d'un refus le rend
invisible, pas inoffensif. Un garde qui corrige en silence est un garde qu'on
ne peut pas déboguer.

### Le correctif (0194)

Le garde protège contre une écriture **directe du client** — PostgREST écrit
sous `authenticated`. Il n'a jamais eu pour objet d'entraver les fonctions
d'approvisionnement, `SECURITY DEFINER`, propriété de `postgres`, qui portent
déjà des contrôles **plus stricts** que lui. On distingue les deux mondes par
`current_user`.

⚠️ **La règle « super_admin ne se donne pas » reste AVANT ce laissez-passer** :
elle s'applique même au code de confiance. C'est l'invariant de la 0188 et il
ne bouge pas.

### ⚠️⚠️ LE PIÈGE : `current_user` DANS UN DÉCLENCHEUR `SECURITY DEFINER`

**Premier jet appliqué en production, faux, et dangereux.** Le garde restait
`SECURITY DEFINER` et testait `current_user`. **Dans une fonction SECURITY
DEFINER, `current_user` vaut TOUJOURS le propriétaire** (`postgres`), quel que
soit l'appelant → la condition était vraie à chaque écriture → **le garde ne
gardait plus rien du tout**.

Repéré immédiatement parce que le test de non-régression — « un admin de
groupe ne peut pas se déplacer de groupe » — est passé alors qu'il devait
échouer. Corrigé dans la minute : déclencheur en **`SECURITY INVOKER`**, où
`current_user` désigne enfin celui qui écrit vraiment. Le garde n'a besoin
d'aucun privilège propre : `is_super_admin`, `is_admin_groupe` et
`auth_group_id` sont elles-mêmes SECURITY DEFINER.

**Ne JAMAIS remettre ce déclencheur en SECURITY DEFINER sans retirer le test
`current_user`** — les deux ensemble ouvrent la table en grand. Un garde de
recette dans la 0194 refuse ce retour en arrière.

**Leçon générale : vérifier un correctif de sécurité, c'est vérifier qu'il
REFUSE encore, pas seulement qu'il autorise.** Le premier jet passait le test
« créer un compte marche » à la perfection.

### 🩸 `seed_account` était ouvert à tous les comptes connectés

`SECURITY DEFINER`, **aucun contrôle de permission**, `EXECUTE` accordé à
`authenticated` : elle insère dans `auth.users` avec le rôle, le groupe et
l'école qu'on lui passe. Le garde en **masquait** la moitié (les écritures de
profil étaient annulées) ; l'ouvrir aux fonctions de confiance l'aurait rendue
pleinement exploitable — un admin_groupe fabriqué dans n'importe quel réseau.
**Révoquée dans la 0194** (PUBLIC, anon, authenticated).

⚠️ Ce cas dit qu'il faut **auditer la liste des `SECURITY DEFINER` exécutables
par `authenticated`** à chaque fois qu'on assouplit un garde : ce sont elles
qui héritent de l'assouplissement. Les dix autres qui écrivent dans `profiles`
ont bien leur propre contrôle — vérifié une par une le 2026-09-06.
