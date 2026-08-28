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

## Ce qui est exposé aujourd'hui : rien

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
