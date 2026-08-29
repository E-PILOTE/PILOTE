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

## Inventaire de la dette de déploiement — mesuré le 2026-08-28

**21 migrations** (`0120` → `0140`) sont appliquées en production ; le build
publié reste `3.3.0+20`. 41 tables exigent désormais un verbe de module.

La question n'est pas « la base est-elle plus stricte que le build » — elle l'est
par construction. Elle est : **un écran du build publié laisse-t-il quelqu'un
atteindre un bouton que la base refuse ?** Mesuré, écran par écran, en comparant
les verbes lus dans `origin/main` aux verbes exigés par les politiques.

| cas | verdict |
|---|---|
| écran gardé sur `update` seul, INSERT exigeant `create` (Présences, Cantine, Orientation, Caisse) | **aucun profil livré** n'a `update` sans `create` → inerte |
| Présences Personnel gardé sur `create` seul, UPDATE exigeant `update` | seul le profil Direction a ce module, avec les deux → inerte |
| **état vide offrant la création sans lire `create`** | **9 combinaisons, dont 2 ACTIVES** |

### Les deux qui étaient actives — et ce qui a été fait

`classes`, `eleves`, `inscriptions` : hors d'atteinte, les 37 écoles ont toutes
des classes et des élèves — leur état vide ne s'affiche nulle part.

`matieres` et `programmes` : **36 écoles sur 37 ont zéro matière et zéro
programme**. L'état vide n'y est pas un cas limite, c'est l'écran du jour. Et le
profil « Secrétariat » lit ces deux modules sans détenir `create`.

Une secrétaire qui appuyait sur « Nouvelle matière » perdait donc **tout le lot
d'écritures en attente sur son poste**, en silence.

→ `0141` desserre ces deux `INSERT` (et eux seuls), le temps d'un build.
→ `0142_APRES_LE_BUILD` les rétablit.

Reculer plutôt que d'accorder le verbe au Secrétariat est délibéré : le
catalogue lui donne la LECTURE de toute la structure pédagogique et l'ÉCRITURE à
la Direction. C'est une décision, pas un accident ; on ne la retourne pas pour
rattraper une erreur d'ordre de déploiement.

### À appliquer APRÈS la publication, dans cet ordre

1. `0139_APRES_LE_BUILD_annonces_et_evenements_par_le_verbe.sql`
2. `0142_APRES_LE_BUILD_matieres_et_programmes_par_le_verbe.sql`

### Et `0146`, qui n'attend PAS la même chose

`0146_APRES_TOUS_LES_POSTES_retirer_les_colonnes_firebase.sql` retire
`profiles.fcm_token` et `notifications.fcm_message_id` (décision du 2026-08-29 :
un seul fournisseur, Supabase). Sa condition est **plus forte** que celle de
`0139` / `0142`, et il ne faut pas les confondre :

| | condition |
|---|---|
| `0139`, `0142` | le build est **publié** |
| `0146` | **tous les postes** l'ont reçu |

Les deux premières durcissent un verbe : un poste en retard se voit refuser une
écriture par un `42501`, que le connecteur traite comme fatal — le lot est jeté,
c'est grave mais la synchro repart.

`0146` supprime une colonne que les postes en retard **envoient encore** dans
leurs upserts `profiles`. PostgREST répond alors `42703`, que
`_fatalResponseCodes` (`^22`, `^23`, `^42501`) **ne reconnaît pas** : le
connecteur ne complète pas la transaction, il rejoue le lot indéfiniment. Ce
poste n'envoie plus rien, jamais, sans aucun message à l'écran.

Vérifier avant d'exécuter, et s'abstenir au moindre doute sur le parc :

```sql
SELECT count(*) FROM profiles WHERE fcm_token IS NOT NULL;   -- doit valoir 0
```

Deux colonnes nulles ne coûtent rien. Une école dont les inscriptions ne
remontent plus coûte tout.

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

---

## `0147` — celle qui va AVANT le build (2026-08-29)

Les autres migrations en attente attendent la publication. **Celle-ci la
précède**, et l'ordre inverse casse la délibération dans toutes les écoles.

L'écran Passage (`/user/passage`) n'était dans aucun catalogue. Le garde de
routes n'arme ses verrous que si `moduleSlugForLocation()` reconnaît la page ;
un slug inconnu vaut « route native », comme le Tableau de bord — donc **ni
verrou d'impayé, ni verrou de plan, ni verrou de profil d'accès**, sur l'écran
qui décide qui passe et qui redouble. Le droit `conseils.update` gardait le
bouton d'entrée, pas la page.

`0147` crée le module `passage` et lui **recopie à l'identique** les droits et
les plans de `conseils`. Personne ne gagne ni ne perd un droit — vérifié :

| slug | lignes | lecture | création | m.à j. | suppr. | `own_classes` | plans |
|---|---|---|---|---|---|---|---|
| `conseils` | 21 | 21 | 14 | 14 | 7 | 7 | institutionnel, pro |
| `passage`  | 21 | 21 | 14 | 14 | 7 | 7 | institutionnel, pro |

| ordre | conséquence |
|---|---|
| **base d'abord** ✅ | l'ancien build gagne une entrée « Passage » qui mène au gîte `/user/m/passage` (« en cours de développement »). Le vrai écran reste atteignable par le bouton des Conseils. Coût : une ligne redondante chez 33 écoles, jusqu'à la publication. |
| build d'abord ❌ | le nouveau build exige `passage.can_read`, que personne n'a encore : « Ouvrir la délibération » renvoie tout le monde au tableau de bord. La délibération devient impossible partout. |

**Appliquée en production le 2026-08-29.** Le build qui l'accompagne
(`_moduleRoutes['passage']`) est dans `main`, non publié.

Garde côté code : `test/toute_page_ecole_est_un_module_test.dart` — il ne
surveille pas `passage`, il surveille **la classe entière du défaut** : toute
route `/user/*` est un module, ou figure dans la liste des routes natives avec
sa raison écrite.
