# Ordre de déploiement — base, build, profils d'accès

> Relevé le 2026-08-28. À relire **avant** de toucher aux profils d'accès d'un
> groupe, et **avant** de publier le prochain build.

## L'état du jour

| | où | état |
|---|---|---|
| Migrations `0118` → `0134` | base de production | **appliquées** |
| Changements applicatifs correspondants | `main` local | **12 commits non poussés** |
| Build publié aux écoles | `3.3.0+20` | antérieur à ces commits |

**La base est donc plus stricte que l'application que font tourner les écoles.**
C'est exactement le mode de défaillance que ces migrations éliminent — il faut
donc être précis sur ce qui est vraiment exposé.

## ⚠️ Ce qui était exposé, et que cette page affirmait à tort ne pas l'être

> Corrigé le 2026-08-28, quelques heures après la première rédaction.

La section ci-dessous concluait « rien n'est exposé aujourd'hui » à partir d'une
seule requête : les profils détenant `update` **sans** `create`. La requête était
juste. Elle ne couvrait pas le cas inverse, et c'est celui qui était ouvert :

**un profil qui LIT un module, devant un écran qui offre la CRÉATION à
quiconque sait lire.**

Cinq écrans gardaient leur barre d'outils par `PermissionGate(create)` mais
laissaient leur `AdminEmptyState` — le second chemin vers le même formulaire —
gardé par `readOnly` seul, ou par rien. Or l'état vide est celui d'une école qui
démarre : c'est le premier écran que tout le monde voit, et le seul où l'action
est au centre, en gros.

| écran | table | verbe exigé depuis | profil livré qui lit sans créer |
|---|---|---|---|
| Matières | `subjects` | 0131 | Secrétariat |
| Programmes | `school_programs` | 0135 | Secrétariat |
| Classes | `classes` | 0129 | Secrétariat |
| Élèves | `students` | 0131 | Comptabilité, Enseignant, Vie scolaire |
| Inscriptions | `class_enrollments` | 0131 | les mêmes |

Chacune de ces portes produisait un **42501**, code fatal : le lot d'écritures
entier en attente sur le poste était jeté. Les cinq sont fermées, et le garde
`test/porte_de_creation_test.dart` les tient.

**La leçon est sur la méthode, pas sur la base** : une sonde ne prouve que ce
qu'elle interroge. Vérifier `update sans create` ne dit rien de `read sans
create`, et un écran peut offrir une écriture par plusieurs portes.

## Ce qui reste vrai du premier relevé

Mesuré profil par profil sur la base de production :

- **Aucun profil livré ne détient `update` sans `create`** sur les dix modules
  dont la RLS exige désormais un verbe (`presences-eleves`, `cantine`,
  `orientation`, `discipline`, `infirmerie`, `bibliotheque`, `matieres`,
  `classes`, `examens`, `conseils`). Les écrans du build 20 qui gardent une
  feuille de pointage sur le seul `update` ne peuvent donc pas produire de
  42501 : quiconque atteint le bouton possède aussi `create`.
- Les écrans Discipline et Infirmerie du build 20 lisent déjà `create`,
  `update` et `delete` séparément : ils correspondent à la RLS.

## Ce qui devient dangereux si l'on tighten les profils avant de publier

⚠️ **C'est le piège, et il inverse une recommandation faite plus tôt.**

Le bouton « Reconduire les classes » (écran Passage) est gardé, **dans le build
20**, par `conseils.update`. Depuis la migration `0129`, la base exige pour
créer une classe :

```
classes.create  OU  conseils.validate  OU  chef d'établissement
```

Le profil **Enseignant** livré au catalogue détient `conseils.update` (bouton
actif) et **pas** `conseils.validate`. Il ne passe la base que parce qu'il
détient aussi `classes.create` — précisément l'excès de droits qu'il a été
recommandé de retirer.

**Retirer `classes.create` ou `matieres.create` au profil Enseignant AVANT de
publier le nouveau build rend « Reconduire les classes » fatal** : le bouton
reste actif, la base refuse en 42501, et le connecteur PowerSync jette le lot
d'écritures entier en attente sur le poste.

## Migration en attente : `0139` (communication)

`database/migrations/0139_APRES_LE_BUILD_annonces_et_evenements_par_le_verbe.sql`
est **écrite et non appliquée**, volontairement.

Elle durcit `announcements` et `events` par le verbe des modules `annonces` /
`evenements`, créés par la migration `0138`. Le build qui porte les gardes
correspondants (`exigerDroitComm`) n'est pas encore publié : appliquer `0139`
maintenant rendrait la publication fatale pour tout profil sans le verbe.

`0138`, elle, **est appliquée** — elle est purement additive (une catégorie,
trois modules, 105 lignes de permissions reproduisant à l'identique le partage
qui existait en dur dans le code). Rien ne change pour personne tant que le
build n'est pas publié.

## L'ordre à respecter

1. **Pousser les 12 commits et publier le build.** Il aligne les écrans sur la
   base : « Reconduire » passe à `conseils.validate`, et Cantine / Présences /
   Orientation exigent `create` en plus d'`update`.
2. **Ensuite seulement**, resserrer les profils d'accès :
   - retirer `matieres.create/update` et `classes.create/update` au profil
     **Enseignant** (un professeur ne devrait pas pouvoir changer un
     coefficient, qui fixe toutes les moyennes de la classe) ;
   - décider du drapeau `sync_medical` de l'Enseignant : tant qu'il détient
     `infirmerie.can_read`, le journal médical de **toute l'école** descend sur
     son poste — le `data_scope` filtre l'affichage, pas la synchronisation.
3. **Ne pas déployer de migration qui durcit un verbe sans son build.** La
   règle apprise en `0129` vaut aussi dans le temps : les deux moitiés bougent
   ensemble, ou l'écart devient un lot perdu.

## Vérifier avant de resserrer un profil

```sql
-- Un profil qui pourrait atteindre un bouton sans passer la base.
SELECT ap.name, m.slug,
       bool_or(pp.can_create) AS c, bool_or(pp.can_update) AS u
FROM access_profiles ap
JOIN profile_permissions pp ON pp.profile_id = ap.id
JOIN modules m ON m.id = pp.module_id
GROUP BY ap.name, m.slug
HAVING bool_or(pp.can_update) AND NOT bool_or(pp.can_create);
```

Toute ligne rendue par cette requête est un 42501 en attente — donc un lot
d'écritures perdu, en silence, sur le poste de quelqu'un.

Et **la même requête sur `can_read`**, qui manquait :

```sql
SELECT ap.name, m.slug
FROM access_profiles ap
JOIN profile_permissions pp ON pp.profile_id = ap.id
JOIN modules m ON m.id = pp.module_id
GROUP BY ap.name, m.slug
HAVING bool_or(pp.can_read) AND NOT bool_or(pp.can_create);
```

Ses lignes ne sont pas des défauts en soi — lire sans créer est un réglage
légitime, et c'est même le plus courant. Elles ne deviennent un 42501 que si un
écran du module offre la création sans lire le verbe. C'est ce croisement-là
qu'il faut refaire après chaque nouvel écran, et que le garde
`test/porte_de_creation_test.dart` automatise du côté du code.
