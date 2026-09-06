---
name: chargement-espaces-en-ligne
description: "Pourquoi les espaces super_admin et admin_groupe rechargent tout, tout le temps — 35 providers sans keepAlive, 8 à 13 requêtes par écran, aucune persistance ; plan en 3 niveaux et le piège des 4 providers jamais invalidés (mesuré le 2026-09-06)"
metadata:
  node_type: memory
  type: project
---

# « Tout se charge à tout moment » — mesuré le 2026-09-06

Remarque du fondateur, la veille de la présentation au ministre. Elle est
fondée, et le coût est chiffrable.

## Ce que coûte l'ouverture d'un écran

⚠️ **Premier comptage FAUX, corrigé le jour même.** Un `grep .from(` mélange
les lectures et les écritures : les actions d'un écran vivent dans le même
fichier. « Économie & licences » n'en fait que **3**, pas 13. Le comptage juste
ne retient que ce qui se trouve dans le corps d'un provider asynchrone
(`docs/memoire/froid.py` et le script `lectures.py`).

| Écran | **Lectures** par ouverture | État |
|---|---|---|
| Tableau de bord fondateur | **10** | gardé au chaud |
| Abonnement du groupe | 9 | gardé au chaud |
| Chiffres officiels (examens) | 8 | gardé au chaud |
| Tableau de bord groupe | 8 | gardé au chaud |
| Rapports | 7 | gardé au chaud |
| Profils d'accès | 7 | gardé au chaud |
| Économie & licences | 3 | **froid** |

Et **elles partaient l'une après l'autre** : aucun `Future.wait` dans toute
l'application. Sur une liaison à 400 ms, dix allers-retours en file font
**quatre secondes** pour afficher la page qu'on ouvre en premier chaque matin.

## Pourquoi ça recommence à chaque fois

**35 providers sont `autoDispose` SANS `ref.keepAlive()`** : dès que l'écran
n'est plus regardé, la donnée est détruite. Revenir dessus retélécharge tout.
Liste produite par `scratchpad/froid.py` — parmi les plus visités :
`economieProvider`, `adminFeesProvider` (5 providers, aucun gardé),
`licencesDuGroupeProvider`, `accesGroupeProvider`, `institutionTypesProvider`,
`adminAcademicYearsProvider`, `examReferentialProvider`.

⚠️ **Ce N'EST PAS un problème de `skipLoadingOnRefresh`.** Erreur commise puis
corrigée le jour même : dans Riverpod 2.6, `skipLoadingOnRefresh` vaut **déjà
`true` par défaut** — les 41 endroits qui le passent explicitement ne changent
rien. Celui qui compte est `skipLoadingOnReload` (défaut `false`), et il ne
concerne que les recalculs par dépendance, rares ici.

⚠️ **Ce n'est pas non plus l'état d'authentification.** `_ecouterLesSessions`
mémorise la session sans jamais réémettre l'état : un renouvellement de jeton
n'invalide rien. (`ProfileModel` n'a toutefois ni `==` ni `hashCode`, et 164
endroits observent l'état entier plutôt qu'un champ — à surveiller si l'on
ajoute un jour une réémission.)

**Et il n'existe AUCUNE persistance** pour ces deux espaces : c'est la règle
d'architecture (offline-first = PowerSync = personnel scolaire uniquement).
À chaque ouverture de l'application, tout repart du réseau.

## Plan en trois niveaux

**Niveau 1 — garder au chaud en mémoire. ✅ FAIT le 2026-09-06.**

`core/utils/garder_au_chaud.dart` : un `keepAlive` **borné dans le temps**.
**35 providers froids → 1** (le dernier ne porte aucune donnée : c'est un objet
d'actions). Revenir sur un écran dans le délai coûte **zéro requête**.

Trois durées, nommées par ce qu'elles portent — l'ordre porte le raisonnement,
pas les valeurs :

| Durée | Pour quoi | Pourquoi |
|---|---|---|
| `kChaudContrat` = 1 min | licence de tutelle, droit d'accès | change depuis l'espace du fondateur, sur une AUTRE machine, sans temps réel ici |
| `kChaudCourant` = 5 min | écoles, frais, comptes, dossiers | bouge à la journée |
| `kChaudReferentiel` = 20 min | types d'établissement, niveaux, vocabulaire d'examen | change quelques fois par an |

⚠️ **Pas de `keepAlive()` nu.** Un ministère laisse l'application ouverte la
journée : sans échéance, il verrait le soir les chiffres du matin, sans le
savoir. Le silence d'une donnée périmée est le même défaut que le silence
d'une lecture ratée.

> 🩸 **ET LES INVALIDATIONS, DANS LE MÊME LOT.** Deux lectures n'étaient jamais
> rafraîchies après écriture, et étaient justes **parce qu'**elles étaient
> froides. Ajoutées : `comptesAdminParGroupeProvider` (on nomme un
> administrateur → la fiche du groupe affichait « aucun » pendant cinq minutes)
> et `adminRattachementProvider` (on coche un niveau → le rattachement
> l'ignorait). Les deux autres suspectes sont sans risque : `institution_types`
> n'est écrit **nulle part** en Dart (référentiel semé en base), et
> `licencesDuGroupeProvider` est passé à la durée `contrat`.
>
> `test/garder_au_chaud_test.dart` (7 tests) garde le couple cache+invalidation,
> dont deux tests qui exercent réellement le minuteur.

**Niveau 2 — afficher avant de charger. ❌ NON FAIT, et volontairement.**

C'était le bon plan **avant** le niveau 3. Après, l'arithmétique s'est
retournée :

| | Ouverture d'un tableau de bord |
|---|---|
| Avant tout | 8 à 10 allers-retours en file ≈ **3 à 4 s** |
| Après niveau 3 | 1 à 2 allers-retours ≈ **0,4 à 0,8 s** |
| Après niveau 1 (retour sur l'écran) | **0 requête** |
| Ce que le niveau 2 ajouterait | ~0,8 s gagnées **une fois par lancement** |

Pour ces 0,8 s il faudrait : sérialiser cinq modèles riches, un cache disque,
un affichage d'âge, et **accepter qu'un tableau de bord de ministère montre des
chiffres d'hier**. C'est exactement la famille de défauts retirée les 5 et
6 septembre. Le rapport bénéfice/risque ne le justifie plus.

⚠️ **La variante qui, elle, vaudra le coup un jour** : non pas pour la vitesse
mais **pour le hors-ligne**. Un ministère qui ouvre l'application sans réseau
voit aujourd'hui des tirets. Un dernier relevé daté — « voici ce que je savais
le 6 septembre à 8 h » — vaudrait mieux. La bonne implémentation est alors de
cacher les **lignes brutes** de chaque lecture, pas les modèles calculés : le
même code d'agrégation les rejoue, rien n'est dupliqué, et rien n'a besoin
d'être sérialisé à la main. À reprendre quand le hors-ligne des espaces admin
deviendra un vrai besoin — pas avant.

**Niveau 3 — réduire le nombre d'allers-retours. ✅ FAIT le 2026-09-06.**

Et **pas** en écrivant des RPC d'agrégation, qui auraient dupliqué la logique
métier entre Dart et SQL sur des écrans qui portent de l'argent. Il suffisait
de cesser d'attendre chaque requête à son tour : chaque bloc `try/catch` est
devenu une fonction locale, et les fonctions partent ensemble.

| Écran | Avant | Après |
|---|---|---|
| Tableau de bord fondateur | 10 en file | **1 vague** |
| Rapports | 7 en file | **1 vague** |
| Tableau de bord groupe | 8 en file | **2 vagues** |
| Abonnement du groupe | 9 en file | **2 vagues** |

Mêmes requêtes, mêmes agrégats, mêmes chiffres — vérifié ligne à ligne, les
appels réseau sont identiques au caractère près. Seul l'ordonnancement change.

⚠️ **CE QUI REND CE DÉCOUPAGE DANGEREUX, ET CE QUI LE GARDE.** Certains calculs
lisent des tables que seule une des lectures remplit : `abonnementsByStatus`,
`planList`, `deptList` côté fondateur ; la liste `schools` côté groupe ; les
formules qui attendent les familles côté abonnement. Les remonter au-dessus de
l'attente les ferait travailler sur du vide — **sans erreur, sans trace, avec
des chiffres faux à l'écran**. `test/les_lectures_partent_ensemble_test.dart`
(9 tests) surveille l'ordre autant que la vitesse.

⚠️ Chaque lecture garde son propre `catch`. Sans cela, `Future.wait` remonte la
PREMIÈRE erreur et abandonne les autres : un échec isolé viderait toute la page
au lieu d'une seule mesure.

Restent en file : `adminAccessProvider` (7) et `officialFiguresProvider` (8) —
leurs lectures s'emboîtent réellement les unes dans les autres, et le premier
porte encore 7 `catch (_) {}` à nommer d'abord.

## ⚠️ La règle qui encadre tout cache ici

Ces écrans portent de l'**argent**, des **quotas** et des **licences**. Un
chiffre en cache affiché comme un fait est exactement le défaut retiré les
2026-09-05/06 (cf. [[escalade-privileges-profiles]] pour la même famille de
silence). **Un cache doit DIRE son âge.** « Mis à jour il y a 3 min » n'est pas
un ornement : c'est ce qui le rend honnête. Et jamais de cache muet sur un
chiffre qui déclenche une action.

## Décision du 2026-09-06

**Niveau 3 livré** (voir ci-dessus) : il ne change aucune requête, donc aucun
chiffre — c'est ce qui le rend sûr à livrer tout de suite.

**Niveau 1 livré le lendemain**, cache ET invalidations dans le même lot, avec
les tests qui gardent le couple.

**Niveau 2 refusé**, arithmétique à l'appui (voir ci-dessus) : après les
niveaux 3 et 1, il n'achèterait plus que 0,8 seconde une fois par lancement, au
prix d'un tableau de bord de ministère susceptible d'afficher les chiffres de
la veille. Décision prise, pas oubliée.
