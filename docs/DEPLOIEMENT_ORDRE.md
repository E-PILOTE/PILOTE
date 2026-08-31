# Ordre de déploiement — base, build, profils d'accès

> Relevé le 2026-08-28. À relire **avant** de toucher aux profils d'accès d'un
> groupe, et **avant** de publier le prochain build.

## `0151` → `0154` — le référentiel congolais et la tutelle (2026-08-30)

Toutes **AVANT_LE_BUILD**, toutes **appliquées**. Aucune n'attend un build : ce
sont des ajouts et des corrections côté serveur.

| migration | ce qu'elle fait | attend un build ? |
|---|---|---|
| `0151` | `institution_types`, `statut_reglementaire`, colonnes de parcours | non |
| `0152` | durées, `BT`, passerelles réécrites sur source | non |
| `0153` | `school_groups.tutelle` + héritage par déclencheur | non |
| `0154` | l'admin groupe peut enregistrer barème et opt-in partenaires | **non — et elle RÉPARE le build déjà déployé** |
| `0155` | le référentiel national des examens est réservé aux ministères | non |
| `0156` | `search_path` figé sur nos fonctions | non |
| `0157` | relancer un ticket le rouvre vraiment | **non — répare aussi le build déployé** |
| `0158` | l'agrément du groupe + les deux RPC de tutelle | non |
| `0159` | le prix suit le nombre d'écoles | **OUI — le build doit lire les 4 colonnes de tranche** |
| `0160` | licence annuelle de tutelle + coûts d'exploitation réels | oui (écrans neufs) |
| `0161` | la circulaire de tutelle | oui (écrans neufs) |
| `0162` | une fonction de déclencheur n'est pas une API | non |

### `0139` et `0142` — APPLIQUÉES le 2026-08-31

Leur condition était explicite : « pousser les commits → **publier le build** →
appliquer ». Le build **3.4.1 (build 25) est publié et vérifié en ligne**, et
les deux gardes qu'il devait porter sont bien dedans :

| garde | commit | dans `v3.4.1` |
|---|---|---|
| `exigerDroitComm` (0139) | `20ac4ec` | ✅ |
| `canCreate` sur l'état vide (0142) | `fa87ac4` | ✅ |

**Mesuré après application, sous identités réelles (transaction annulée) :**

| | résultat |
|---|---|
| directeur — verbe `annonces:create` | **oui**, et il publie |
| directeur — voit l'annonce de GROUPE (`school_id IS NULL`) | **1** — la promesse tenue |
| enseignant — verbe `annonces:create` | **non** |
| enseignant — publie | **refusé 42501** |
| enseignant — supprime / modifie celle du directeur | **0 ligne** |
| enseignant — **lit** celle du directeur | **1** — il la voit, il n'y touche pas |

Et le risque de tout fermer par mégarde, écarté par mesure :

| rôle | matières | programmes | annonces |
|---|---|---|---|
| directeur · proviseur | ✅ | ✅ | ✅ |
| enseignant | ✅ | ✅ | ❌ |
| **secrétaire** | ❌ | ❌ | ✅ |
| comptable · surveillant | ❌ | ❌ | ❌ |

La secrétaire n'a pas `matières`/`programmes` — **c'est exactement le profil qui
produisait le `42501` fatal** et avait fait reculer `0141`. Le build publié ferme
désormais la porte de l'état vide, donc elle ne peut plus appuyer.

### `0146` — TOUJOURS SUSPENDUE, et voici la vraie raison

Sa condition est « attendre que **TOUS** les postes aient reçu le build ». Ce
qu'on peut mesurer aujourd'hui : 344 comptes, **10 ont ouvert une session**,
19 sessions au total, **2 actives sur 48 h**, et **1 seul poste** a signalé sa
version. Autrement dit : il n'y a pas encore de parc.

⚠️ **Mais cela ne suffit pas à conclure.** Le produit est **hors-ligne d'abord** :
un poste peut rester éteint des semaines puis synchroniser. « Aucune session
récente » ne prouve donc rien sur ce qu'il enverra au retour. C'est précisément
le scénario contre lequel `0146` met en garde.

**Ce qui a changé le 2026-08-31** : un blocage de file n'est plus muet. Le
connecteur consigne désormais un désaccord de schéma (`42703` et compagnie) dans
`sync_failures` avec `kind = 'blocage'`, et le bandeau dit « ce poste n'envoie
plus rien, **rien n'est perdu**, mettez à jour ». Le jour où un build portant
cette détection sera adopté, retirer une colonne cessera d'être un pari : un
poste resté en arrière le DIRA au lieu de se taire.

> ⚠️ On n'a PAS rendu `42703` fatal. Ce serait jeter les écritures de l'école
> pour lui épargner un bandeau — le remède serait pire. Le lot reste en file,
> intact, et repart après la mise à jour.

### `0159` → `0162` — la grille, la licence, la circulaire (2026-08-31)

| migration | ce qu'elle change | mesuré |
|---|---|---|
| `0159` | la falaise Pro→Institutionnel (**×11,4 à la 11ᵉ école**) disparaît ; prix = base + tranches dégressives | grille vérifiée en base : 1=30 000 · 2=40 000 · 10=110 000 · 21=174 000 |
| `0160` | `tutelle_licences` (montants libres) + `platform_costs` (ce que l'infra coûte) | Supabase Pro 25 $/mois + PowerSync Cloud Pro 49 $/mois ≈ **45 140 XAF/mois** |
| `0161` | circulaire descendante + accusé de lecture par établissement | MEPSA publie → **25 établissements / 6 groupes** ; un groupe privé émet → `42501` |
| `0162` | 51 fonctions de déclencheur n'étaient plus appelables par `anon` | `triggers_ouverts_a_anon : 0`, héritage tutelle + agrément toujours OK |

#### ⚠️ `0159` attend le build

Quatre colonnes neuves (`extra_school_*_xaf`) portent le prix au-delà de la
première école. **Un build antérieur ne les lit pas** : il afficherait la base
seule — 30 000 pour un groupe de trois écoles qui en doit 50 000. La facture,
elle, est déjà juste (les quatre fonctions de facturation ont été réécrites).
L'écart est donc *visible* et non destructeur, mais il faut publier vite.

#### Deux règles mesurées ce jour-là

> **`REVOKE ... FROM anon, authenticated` ne suffit pas.** PostgreSQL accorde
> `EXECUTE` à **PUBLIC** par défaut, et les deux rôles en héritent. Après un
> REVOKE nommé, `has_function_privilege('authenticated', …)` renvoyait encore
> `true`. C'est `FROM PUBLIC` qui fait le travail.

> **Retirer `EXECUTE` n'empêche pas un déclencheur de tourner.** Le privilège
> est contrôlé à la CRÉATION du déclencheur, pas à chaque déclenchement.
> Vérifié : privilège retiré, `updated_at` passe quand même de 2000-01-01 à
> maintenant.

#### Ce qui reste NON déployé

Les deux flux PowerSync qui feraient descendre les circulaires jusqu'au chef
d'établissement **hors ligne** sont écrits **en commentaire** dans
`powersync/config/sync-rules.yaml`. Ils n'ont pas été validés contre le moteur
(`circulaires` n'est pas filtrable par `school_id` sans JOIN en paramètres).
À reprendre au tableau de bord PowerSync Cloud : coller, **Validate**, puis
**Deploy** — jamais à l'aveugle. Aujourd'hui la circulaire est reçue par
l'**administrateur de groupe**, en ligne.

### `0155` → `0157` — la chasse aux écritures muettes (2026-08-30)

Toutes **AVANT_LE_BUILD**, appliquées et vérifiées. Aucune n'attend un build ;
deux d'entre elles **réparent le build déjà déployé**.

| migration | ce qu'elle corrige | mesuré avant |
|---|---|---|
| `0154` | l'admin groupe n'enregistrait ni barème ni opt-in partenaires | `0 ligne`, `10.00 → 10.00` |
| `0155` | n'importe quel admin de groupe **privé** écrivait le référentiel NATIONAL | BAC modifié, **35 sessions** réécrites, règle d'un autre groupe supprimée |
| `0156` | `search_path` non figé sur 33 fonctions, dont la garde RLS de la messagerie | — |
| `0157` | relancer un ticket résolu ne le rouvrait pas | `0 ligne`, statut reste `resolved` |

#### La règle à retenir

> **Un UPDATE ou un DELETE que le `USING` d'une politique écarte ne lève PAS
> d'erreur.** Zéro ligne, réponse 204. L'écran affiche « enregistré ».
> Seul un INSERT refusé par un `WITH CHECK` lève 42501.

Conséquence pratique : **fermer une table ne suffit pas** — il faut aussi
retirer le bouton, sinon on échange une destruction silencieuse contre un clic
silencieux. C'est pourquoi `0155` s'accompagne d'un passage en lecture seule
côté Flutter pour les groupes qui n'administrent pas le référentiel.

Le garde `test/ecritures_postgrest_test.dart` oblige désormais à inscrire toute
NOUVELLE table écrite depuis l'application, après contrôle de ses politiques.

#### `subscription_reminder_log` : l'alerte est un faux positif

L'analyseur la signale « RLS activée, aucune politique ». C'est **voulu** :
elle n'est écrite que par le job `pg_cron` (donc en `postgres`), et aucune ligne
de Dart ne la lit. Deny-all pour `authenticated` est l'état correct — lui
ajouter une politique l'ouvrirait sans raison.

### ⚠️ Ce qui reste suspendu à une ADOPTION, pas à une publication

| | condition |
|---|---|
| `school_groups.tutelle` → `NOT NULL` | build qui la renseigne **publié ET adopté**. La passer NOT NULL maintenant casserait la création de groupe depuis le build déployé (23502, famille fatale). |
| `schools.tutelle` → suppression | **jamais tant qu'un poste peut l'envoyer.** Ce serait la faute `0146` : 42703 n'est pas dans `_fatalResponseCodes`, donc rejeu silencieux et infini. Elle reste une copie tenue par déclencheur. |

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
| `0146` | **tous les postes** l'ont reçu (build ≥ 24) — mesurable depuis `0150`, voir plus bas |

Les deux premières durcissent un verbe : un poste en retard se voit refuser une
écriture par un `42501`, que le connecteur traite comme fatal — le lot est jeté,
c'est grave mais la synchro repart.

`0146` supprime une colonne que les postes en retard **envoient encore** dans
leurs upserts `profiles`. PostgREST répond alors `42703`, que
`_fatalResponseCodes` (`^22`, `^23`, `^42501`) **ne reconnaît pas** : le
connecteur ne complète pas la transaction, il rejoue le lot indéfiniment. Ce
poste n'envoie plus rien, jamais, sans aucun message à l'écran.

### ⚠️ Le seuil n'est plus 3.3.1+21 — et il n'est pas OBSERVABLE (2026-08-29)

Deux constats faits en interrogeant la base et le dépôt de distribution :

**1. Le seuil correct est `build_number ≥ 24`, pas 21.** `app_releases` ne
contient qu'une ligne — **3.3.0 build 20** — et le dépôt public
`E-PILOTE/telechargements` ne porte qu'une publication, `v3.3.0`. Les builds
**3.3.1+21 et 3.4.0+22 n'ont JAMAIS été distribués**. Le premier binaire sans les colonnes
Firebase que le parc puisse réellement recevoir — et qui sache en outre se
signaler — est donc **3.4.0+24**. Écrire 21 dans une consigne enverrait quelqu'un vérifier un seuil
qu'aucun poste n'a jamais pu franchir.

**2. Rien ne disait quelle version tourne où — corrigé par la migration 0150.**
`build_number` n'existait que dans `app_releases`, c'est-à-dire ce qui est
PROPOSÉ, jamais ce qui est INSTALLÉ.

`0150` ajoute `app_installations` et la RPC `signaler_version()`, appelée une
fois par session au même endroit que la vérification de mise à jour. L'écran
**super_admin → Versions** montre le relevé, et refuse de conclure tant qu'un
seul profil n'a rien signalé.

⚠️ **L'absence de signalement EST le signal.** Les builds antérieurs à 24 n'ont
pas ce code : ils n'apparaîtront jamais. Un profil absent est donc soit sur une
version ancienne, soit jamais revenu — deux risques pour `0146`, indiscernables,
donc comptés ensemble. Ne jamais lire « à jour » sans « n'ont rien signalé ».

Et elle n'est pas non plus forçable : `is_mandatory` / `min_build` rendent la
bannière rouge et non refermable, mais **ne bloquent pas l'application** — un
poste peut travailler indéfiniment sur une version ancienne.

Conséquence pratique : `0146` ne doit pas être appliquée sur une impression.
Tant qu'il n'existe pas de relevé des versions installées, la seule position
tenable est de **ne pas exécuter `0146`** — les deux colonnes sont vides
(0 valeur sur 344 profils, 0 sur 121 notifications) et ne coûtent rien à
laisser en place. Le gain du DROP est cosmétique ; le risque est une synchro
morte en silence sur les postes retardataires.

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

### ⚠️ « Publié » ne veut pas dire « installé » (2026-08-30)

Le build 3.4.0+24 est publié : la publication GitHub est levée, et la ligne
`app_releases` est écrite. La condition littérale de `0139` / `0142` est donc
remplie — **et il ne faut pourtant pas les appliquer aujourd'hui.**

La condition « le build est publié » avait été écrite quand rien ne permettait
d'observer le parc. Elle servait de substitut à la vraie question : *les postes
qui écrivent ont-ils la garde `exigerDroitComm` ?* Le jour de la publication, la
réponse est **non pour tout le monde** — la bannière vient d'apparaître, personne
n'a encore installé.

Appliquer `0139` maintenant rendrait l'écriture fatale (42501) pour tout profil
sans le verbe sur un poste resté en 3.3.0 : le lot est jeté, la synchro repart,
mais **le travail de ce lot est perdu**.

Le relevé du parc (`0150`) permet enfin de poser la vraie question. La règle
devient :

| migration | condition réelle |
|---|---|
| `0139`, `0142` | le parc a **majoritairement** adopté le build ≥ 24, et les retardataires sont identifiés |
| `0146` | **zéro** profil muet et **zéro** en retard — aucune tolérance |

Voir **super_admin → Versions**, encart « Le parc ».

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

## `0148` — carte scolaire, même ordre que `0147` (2026-08-29)

Nouveau module `cartes` (SCOLARITÉ), qui reçoit **à l'identique** les plans et
les droits de `documents` : 35 lignes, 35 en lecture, 14 en export — mêmes
chiffres des deux côtés. Aucune RLS touchée : le module ne fait que LIRE
`students` et `class_enrollments`, il n'écrit rien, donc il ne peut pas
produire de 42501.

**Appliquée en production le 2026-08-29**, avant le build, pour la même raison
que `0147`.

### État des migrations en attente, après ce tour

| migration | quand |
|---|---|
| `0147` délibération = module | ✅ appliquée (avant le build) |
| `0148` carte scolaire = module | ✅ appliquée (avant le build) |
| `0139` annonces/événements par le verbe | ⏳ build **publié le 2026-08-30** — mais attendre l'ADOPTION, voir ci-dessous |
| `0142` matières/programmes par le verbe | ⏳ **après** la publication du build |
| `0146` retrait des colonnes Firebase | 🛑 **suspendue** — seuil réel ≥ build 24 ; le relevé existe depuis `0150`, il faut maintenant qu'il soit **complet** (zéro profil muet) |

⚠️ Les deux familles ne s'attendent pas au même signal : `0139`/`0142` attendent
que le build soit **publié** ; `0146` attend qu'il soit **reçu partout** — une
condition strictement plus forte. `0147`/`0148`, elles, devaient PRÉCÉDER la
publication, et c'est fait.

## `0149` — registre des documents délivrés : ⚠️ elle a une DEUXIÈME condition

Appliquée en production le 2026-08-29 (table `issued_documents`, immuable par
trigger, RLS posée). Mais **la migration seule ne suffit pas** — et c'est le
premier cas du dépôt où une migration dépend d'un déploiement PowerSync.

| ce qu'il faut | fait ? | si on l'oublie |
|---|---|---|
| migration `0149` | ✅ appliquée | — |
| **ligne dans les sync-rules** (`by_school`) | ✅ **déployée le 2026-08-29** | les écritures remontent bien vers Postgres, mais n'appartiennent à aucun bucket : la copie locale disparaît au checkpoint suivant et **l'écran s'affiche vide alors que la donnée existe**. Rien n'est perdu — l'écran ment. |
| build publié | ⏳ | — |

La ligne est déjà écrite dans `powersync/config/sync-rules.yaml` :

```yaml
- SELECT * FROM issued_documents WHERE school_id = bucket.sid
```

Elle se déploie par le tableau de bord PowerSync Cloud (ou la CLI avec un jeton
valide — celui de la session du 28/08 doit être révoqué et régénéré). **À faire
avant de publier le build**, pour la même raison que `0147`/`0148`.

### Pourquoi l'INSERT du registre n'exige AUCUN verbe de module

Contrairement à toutes les autres écritures du dépôt. L'écriture du registre
ACCOMPAGNE la délivrance : elle est faite par quiconque vient de produire le
document. Exiger un droit que l'agent n'a pas ferait échouer l'insertion en
**42501 — fatal** : le journal détruirait le travail de la journée pour avoir
voulu le noter. C'est la règle de la migration `0144`, appliquée ailleurs.

Le contrôle d'accès reste là où il a un sens : l'écran de consultation
(`/user/documents/registre`) vit sous le module `documents` — sous-chemin, donc
même verrou, sans une ligne de plus au catalogue.

## ✅ 3.4.0+24 est publiée au parc (2026-08-30)

La chaîne complète, et chaque maillon vérifié :

| étape | état |
|---|---|
| migrations `0147` · `0148` · `0149` · `0150` | ✅ appliquées |
| sync-rules déployées | ✅ 2026-08-29, diff LIVE ↔ dépôt vide |
| build `3.4.0+24` | ✅ construit, 1 821 tests verts, binaire lancé |
| publication GitHub `v3.4.0` | ✅ levée sur `E-PILOTE/telechargements` |
| ligne `app_releases` | ✅ écrite, `is_mandatory = false` |

**Vérification qui compte** : le fichier téléchargé depuis l'adresse publique a
été confronté au manifeste et au binaire local — les **trois empreintes SHA-256
concordent** (`966f2175…`), et la taille annoncée (35 894 292 o) est la taille
réelle. Le poste refuse d'installer un fichier dont l'empreinte diffère ; une
valeur retapée de travers aurait bloqué toute mise à jour du parc sans que
personne comprenne pourquoi.

`derniere_version('windows','stable')` rend bien 3.4.0 build 24.

⚠️ La mise à jour est **non obligatoire** : la bannière est refermable. Un
secrétariat en pleine saisie de rentrée la ferme et continue ; il la reverra à
la session suivante. Pour forcer, poser `is_mandatory = true` — mais cela ne
bloque toujours pas l'application, cela rend seulement la bannière rouge et
non refermable.

## ✅ Les sync-rules ont été déployées le 2026-08-29

Un seul déploiement, deux lignes, sur l'instance de **production**
(…66759). Déroulé et vérifications :

1. `pull instance` avant de toucher à quoi que ce soit. Le diff LIVE ↔ dépôt
   ne montrait **que les deux lignes attendues** : personne n'avait modifié la
   configuration au tableau de bord, rien à préserver.
2. `deploy sync-config --sync-config-file-path powersync/config/sync-rules.yaml`
   — validation passée, déploiement terminé.
3. `pull instance` de nouveau, pour lire ce qui tourne **réellement** plutôt
   que ce qu'on croit avoir envoyé. Diff LIVE ↔ dépôt : **vide**.
4. Le binaire construit lancé sur ce poste : PowerSync se connecte, valide et
   applique ses checkpoints, **zéro erreur**. Une règle cassée se serait vue
   là.

⚠️ Le jeton utilisé a été fourni pour ce seul déploiement et **doit être
révoqué** au tableau de bord PowerSync Cloud. Il n'a pas été écrit sur le
disque (`PS_ADMIN_TOKEN` en variable de session, jamais `powersync login`).

`powersync/sync-config.yaml` garde la copie de la configuration telle qu'elle
était **avant** ce déploiement : c'est le retour arrière.

## Ce que portait ce déploiement

Un seul déploiement, deux lignes — les deux dans le bucket `by_school` de
`powersync/config/sync-rules.yaml`, déjà écrites dans le dépôt :

| ligne | pourquoi | si on ne déploie pas |
|---|---|---|
| `SELECT * FROM issued_documents WHERE school_id = bucket.sid` | le registre des documents délivrés doit redescendre | l'écran s'affiche **vide** alors que la donnée existe au serveur |
| `SELECT * FROM students WHERE school_id = bucket.sid` — **sans `AND is_active = true`** | un élève archivé quittait le bucket et **disparaissait de tous les postes** | le **registre matricule perd des lignes**, et l'école ne s'en aperçoit qu'à l'inspection |

Le second point n'est pas une amélioration, c'est une **fuite** : `is_active`
est un drapeau d'archivage, pas de suppression, et la sync-rule le traitait
comme une suppression. Coût du retrait : nul aujourd'hui (0 archivé sur 9 106),
négligeable ensuite — quelques milliers de lignes texte par école, à vie. Les
écrans filtrent déjà `is_active` dans leurs propres requêtes.

⚠️ **Le registre matricule sait dire qu'il est incomplet** : il compte les
inscriptions dont l'élève est introuvable en local et l'écrit sur le document.
Tant que le déploiement n'a pas eu lieu, une école qui aurait archivé un élève
verrait donc l'avertissement plutôt qu'un registre faussement complet. C'est un
filet, pas une dispense de déployer.

### Comment déployer (procédure exécutée le 2026-08-29)

⚠️ **Le jeton stocké sur ce poste ne fonctionnait plus** — celui du 28/08, bien
révoqué. Un jeton neuf a été fourni pour le déploiement du 29/08 et doit être
révoqué à son tour. Le diagnostic reste noté ici parce qu'il se reproduira, et
que la réponse du serveur ne dit pas d'elle-même « jeton révoqué » :

| requête envoyée à `accounts.powersync.com` | réponse |
|---|---|
| jeton bidon, ou aucun en-tête `Authorization` | `401 ACCESS_DENIED` |
| chemin d'API inexistant | `404` |
| **le jeton de `~/.config/powersync/config.yaml`** | **`500 — Resource does not exist`** |

Il franchit donc le contrôle d'authentification (ce n'est pas un 401) mais ne
résout plus vers aucune organisation : le PAT a été révoqué côté compte — ce qui
était précisément la consigne de sécurité après la session du 28/08. Rien à
réparer, il faut en refaire un.

**Étape 0 — effacer le jeton mort, qui dort en clair sur le disque :**

```
powersync logout
```

Il est dans `~/.config/powersync/config.yaml`, en texte simple. La doc de la CLI
annonce « secure storage, e.g. macOS Keychain » ; sur Windows, c'est un YAML
lisible par n'importe quel processus du compte. C'est pourquoi la règle du dépôt
([[powersync-deploiement-cli]]) est **de ne pas utiliser `powersync login`** —
elle a été contournée le 28/08, d'où ce fichier.

**Étape 1 — fournir le jeton à la session de terminal, pas au disque :**

```
export PS_ADMIN_TOKEN='jpt_…'
```

(PowerShell : `$env:PS_ADMIN_TOKEN = 'jpt_…'`.) La CLI lit cette variable avant
toute autre source. Elle meurt avec la fenêtre.

⚠️ **Ne jamais coller un PAT dans une conversation, un ticket ou un commit** :
c'est ce qui a brûlé le précédent. Le jeton se crée sur le tableau de bord
PowerSync Cloud, et se révoque au même endroit.

**Étape 2 — déployer, depuis la racine du dépôt :**

```
powersync deploy sync-config --sync-config-file-path powersync/config/sync-rules.yaml
```

`powersync/cli.yaml` pointe déjà sur l'instance de **production** (…66759) — pas
sur Development (…66757). Ne pas le modifier sans relire son en-tête.

**Étape 3 — vérifier ce qui tourne réellement**, plutôt que ce qu'on croit avoir
envoyé :

```
powersync pull instance --instance-id 6a185943234fa2bf51a66759
```

Écrit `powersync/sync-fetched.yaml` (gitignoré). Les deux lignes du tableau
ci-dessus doivent y figurer, et `FROM students` ne doit **pas** porter
`AND is_active = true`.

### Ce que le dépôt garde tout seul

`epilote/test/sync_rules_publient_le_schema_local_test.dart` confronte
`powersync_schema.dart` et `sync-rules.yaml` dans les deux sens : une table
déclarée en local que personne ne publie fait échouer les tests, et
réciproquement. Au 2026-08-29 : **86 tables des deux côtés, aucun écart**.

⚠️ **Ce garde lit le FICHIER, pas les règles DÉPLOYÉES.** Un fichier juste et
non déployé produit exactement la panne qu'il prétend empêcher. Il n'y a pas
d'automatisme possible ici : seule l'étape 3 le dit.

**Avant la publication du build.**

## ⚠️ La prise de photo à la webcam demande une NOUVELLE construction

Le greffon `camera` + `camera_windows` est entré dans `pubspec.yaml` le
2026-08-29. **Il n'est pas dans le build 3.3.1 déjà produit.** Ce qui en dépend
— le bouton « Prendre la photo » sur les trois fiches de personne — n'existera
qu'à la construction suivante.

Rien d'autre n'en dépend : sans le greffon, les fiches ouvraient le sélecteur de
fichiers, et elles le font toujours. Cette fonction n'a donc aucune place dans
l'ordre de déploiement — elle attend simplement le prochain build.

Vérifié : `camera_windows_plugin.dll` est produit, `flutter build windows` sort
à 0, et le binaire construit s'ouvre et synchronise (un greffon qui plante à
l'enregistrement empêcherait l'application d'ouvrir entièrement).
