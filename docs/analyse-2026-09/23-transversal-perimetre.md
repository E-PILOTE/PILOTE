# Verrou 4 — le périmètre des données, balayage transversal

> **Relevé le 2026-09-09** par balayage de `epilote/lib/features/**/*_provider.dart`.
> Point de départ : une trouvaille de l'agent SCOLARITÉ sur le module `cartes`,
> vérifiée puis étendue à toute la plateforme.

## Le mécanisme

Le **verrou 4** de la cascade d'accès borne ce qu'un agent voit à son périmètre :
`profile_permissions.data_scope` vaut `own_classes` (ses classes) ou `own_school`
(toute l'école). Côté code, il s'applique par
`classScopeClause(ref, '<slug du module>', column: '...')`, précédé de
`permissionsLoaded(ref)` — sans quoi la requête part avant que les droits ne
soient descendus.

⚠️ **Chaque écran doit appliquer le périmètre de SON module.** Seize écrans ont
déjà lu `classesProvider` — donc le `data_scope` du module `classes`, pas le
leur. « L'administration affichait un cadenas fermé sur rien — le pire des
défauts, celui qui rend compte d'un succès. » La forme juste est
`classesForModuleProvider(slug)` / `classScopeClause(ref, slug)`.

Référence conforme : `features/students/providers/students_registry_provider.dart:132-133`.

## Le relevé brut

**29 fichiers** interrogent `classes` ou `class_enrollments` **sans** appeler
`classScopeClause`. Ce n'est PAS une liste de 29 défauts : trois familles s'y
mélangent, et il faut les séparer avant de conclure.

### Famille A — écrans hors module : LÉGITIMES

Le tableau de bord d'accueil n'est pas un module de catalogue, il n'a donc pas de
`data_scope` propre. Idem pour les référentiels portés par le GROUPE et pour les
pages de direction, qui lisent l'école entière **par définition** et sont gardées
autrement (sidebar + `redirect` du routeur, deux verrous).

| Fichier | Pourquoi c'est normal |
|---|---|
| `features/user/providers/dashboard_provider.dart` | accueil, pas un module |
| `features/structure/providers/academic_year_provider.dart` | années portées par le groupe (`academic_years.school_id` est NULL) |
| `features/students/providers/etat_rentree_provider.dart` | page de DIRECTION (état de rentrée → circonscription) |
| `features/students/providers/import_eleves_provider.dart` | import de lot, acte d'administration |
| `features/structure/providers/demarrage_provider.dart` | première heure de l'établissement |

### Famille B — à trancher par l'agent de la catégorie

Ces providers servent un module qui **a** un `data_scope`, mais leur requête peut
être bornée ailleurs (par `school_id`, par un provider amont déjà scopé, ou par
une garde d'écran). **À vérifier un par un** — ne rien conclure d'ici.

`features/evaluation/providers/` : `bulletins_provider`, `conseils_provider`,
`evaluations_provider`, `evaluation_overview_provider`, `passage_provider`,
`non_revenus_provider`, `cloture_examen_provider` ·
`features/examens/providers/` : `examens_provider`, `exam_fees_provider`,
`exam_registration_provider` ·
`features/finance/providers/` : `frais_provider`, `paiements_provider`,
`decompte_du_provider` ·
`features/staff/providers/` : `staff_directory_provider`, `staff_dossier_provider` ·
`features/structure/providers/` : `academic_structure_provider`,
`class_subjects_provider` ·
`features/students/providers/` : `registre_matricule_provider`,
`student_dossier_provider`, `frais_inscription_provider` ·
`features/vie_scolaire/providers/` : `presences_provider`, `cantine_provider`,
`orientation_provider`

### Famille C — VÉRIFIÉ, c'est un défaut

#### `features/cartes/providers/cartes_provider.dart` — module `cartes`

```
cartes_provider.dart:84    FROM classes c                    ← aucun classScopeClause
cartes_provider.dart:156   SELECT s.id, …, s.blood_group, …  ← donnée de SANTÉ
cartes_provider.dart:159   FROM class_enrollments e          ← aucun classScopeClause
```

Ni `classScopeClause`, ni `permissionsLoaded` dans tout le fichier — à comparer
avec `students_registry_provider.dart:132-133`, qui pose les deux.

**Ce que ça produit** : un module de catalogue doté d'un `data_scope`, dont
l'écran sert des cartes scolaires nominatives **et le groupe sanguin**, rend
l'école entière à un agent réglé sur `own_classes`. L'administration a coché la
restriction ; elle ne s'applique pas.

**Aggravant** : `cartes` est un module **récent** (absent du relevé de catalogue
du 2026-08-27) — il a été ajouté après la campagne qui a posé le verrou 4 sur les
autres modules, et n'a pas été repris. C'est le patron classique : la règle est
juste, la pièce neuve ne la connaît pas.

**Correction** (reprise de l'agent SCOLARITÉ, vérifiée) : copier
`classScopeClause(ref, 'cartes', column: 'c.id')` + `permissionsLoaded(ref)`
depuis `students_registry_provider.dart:132-133`, ajouter `school_id` aux deux
requêtes, garder l'en-tête par `PermissionGate` (`export`), **puis étendre
`test/perimetre_par_module_test.dart` au dossier `lib/features/cartes/providers`**
— sans quoi la correction se défera en silence au prochain module ajouté.

## Ce que ce balayage dit de plus que les rapports par catégorie

Le défaut n'est pas propre à `cartes`. Le **test gardien**
(`test/perimetre_par_module_test.dart`) énumère des dossiers ; un module créé
après lui échappe par construction. Tant que la sonde liste des chemins au lieu
de partir du **catalogue** (`modules` en base → provider correspondant), chaque
nouveau module rouvrira le même trou.

**Recommandation de fond** : faire dériver la sonde du catalogue, pas de
l'arborescence. Un module actif sans `classScopeClause` dans son provider doit
faire échouer le test, y compris un module créé demain.
