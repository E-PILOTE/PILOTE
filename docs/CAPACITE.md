# Peut-on déployer sur mille écoles ? — état mesuré

> Mesuré le 2026-09-01, à un mois du déploiement annoncé.
> Sonde : `database/checks/0174_le_plafond_de_la_base.sql`.

## La réponse courte

**Non. Pas en l'état, et le premier obstacle n'est pas le logiciel.**

Trois verrous, dans l'ordre où ils se lèvent. Les deux premiers sont des
décisions et de l'argent ; le troisième est du temps, et il ne s'achète pas.

## 1. Le plan d'hébergement — le mur est à quatre écoles

| mesure | valeur |
|---|---|
| plan Supabase | **`free`** |
| plafond de ce plan | 500 Mo |
| base aujourd'hui | **453 Mo — 91 %** |
| coût mesuré d'une école | **12,2 Mo** (≈ 246 élèves, une année de notes) |
| **écoles tenables sur ce plan** | **41** — il y en a déjà 37 |
| projection à 1 000 écoles | **≈ 12 Go**, soit 24 fois le plafond |

⚠️ **Au-delà de 500 Mo, Supabase bascule le projet en lecture seule.** Pas de
dégradation progressive : les écritures échouent. Et sur un produit hors-ligne
d'abord, **ça ne se voit pas tout de suite** — les postes continuent d'accepter
le travail en local, c'est la REMONTÉE qui casse, silencieusement, école par
école. Le seul signal serait celui qu'on surveille déjà pour le pilote : le
silence.

> Ce chiffre n'était surveillé nulle part. Il l'est maintenant : sonde 0174.

**Ce n'est pas un problème de code, c'est une ligne de facture.** Mais il est
antérieur à tout le reste : le pilote lui-même écrit dans cette base.

### Ce qui a été fait tout de suite

Migration `0173` : retrait de deux index redondants **par construction** —
`idx_enrollments_student_year` (doublon exact d'une contrainte unique) et
`idx_students_ine` (préfixe strict d'une autre). **12 Mo rendus**, 465 → 453 Mo,
aucune régression (vérifié au plan d'exécution : 4 blocs, 0,11 ms).

C'est un répit de quelques semaines, pas une solution. Trois autres index, peu
lus, coûteraient **422 Mo à mille écoles** à eux seuls — presque un plan gratuit
entier. Ils sont listés, chiffrés et laissés en place : « jamais lu » est une
preuve plus faible que « redondant », et l'un d'eux (recherche floue sur le nom)
est un choix produit, pas une optimisation.

## 2. Le modèle de synchro — ce que `by_group` fera descendre

**MEPSA et METP sont chacun UN groupe** (14 et 12 écoles aujourd'hui). À
l'échelle nationale, un groupe = un ministère entier, soit des centaines
d'écoles et des milliers d'agents.

Or `by_group` descend sur **chaque poste** des données à l'échelle du groupe.
La plupart sont inoffensives (le référentiel, les barèmes, la liste des écoles :
quelques milliers de lignes). Trois ne le sont pas :

| table | ce qui se passe à l'échelle d'un ministère |
|---|---|
| `story_views` | chaque vue de chaque agent, sur le poste de tous les autres. Croissance en usagers × publications. **Aucun filtre temporel** — PowerSync n'évalue pas `now()`, l'expiration 24 h est filtrée côté client : ce qui est vu reste sur les disques |
| `announcement_reactions` | même loi |
| `student_transfers` | toute la mobilité du ministère sur chaque poste |

⚠️ **Aujourd'hui ces tables sont vides** (0 story, 1 réaction). Le défaut est
donc invisible et le restera jusqu'à ce qu'un ministère publie sa première
annonce nationale. **C'est exactement le genre de chose qu'un pilote sur deux
écoles ne trouvera pas non plus.**

Ce qu'il faudra : soit une purge serveur des vues et réactions anciennes, soit
les sortir de `by_group`. À trancher avant la première vague, pas après.

## 3. Ce qui ne s'achète pas : la preuve d'usage

**Aucun établissement n'a jamais utilisé E-PILOTE.** Une installation déclarée —
la machine de développement. Dix comptes ont ouvert une session, tous avant le
27 août. 37 écoles en base, toutes semées.

Tout ce qu'on sait du produit, on le sait par des tests et des sondes. C'est
beaucoup — 1 962 tests, RLS sur 109 tables sur 109, 173 migrations — et ça ne
remplace pas une secrétaire un lundi matin.

> Passer de zéro école à mille sans étape intermédiaire, ce n'est pas un
> déploiement, c'est un pari. Le pilote existe pour que le premier échec
> coûte deux écoles au lieu de mille.

## Et sur DEUX ministères ?

Le produit est prêt pour deux tutelles : MEPSA et METP existent en base, chacun
avec ses écrans (filières et examens diffèrent), et le pilote est justement
construit pour couvrir une école de chaque. **La difficulté n'est pas là.**

Elle est que les deux ministères tomberaient sur les mêmes trois verrous, avec
un facteur d'échelle deux fois plus grand sur le second.

## L'ordre des choses

| | quoi | qui décide |
|---|---|---|
| **1** | Passer au plan payant. Rien de sérieux ne se fait sous 500 Mo — le pilote lui-même écrit dedans | budget |
| **2** | Le pilote sur deux écoles **réelles** (dossier : `PILOTE.md`) | il manque les deux établissements |
| **3** | Trancher `story_views` / `announcement_reactions` / `student_transfers` dans `by_group` | technique, avant la 1ʳᵉ vague |
| 4 | Vague de 20 à 50 écoles, mêmes sondes | après le pilote |
| 5 | Généralisation | après la vague |

Le reste — signature de code, espace parent, décisions d'audit ouvertes — ne
bloque rien. Voir `CERTIFICAT_SIGNATURE.md`.
