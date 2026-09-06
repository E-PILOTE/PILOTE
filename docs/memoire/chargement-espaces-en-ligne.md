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

**Niveau 1 — garder au chaud en mémoire (≈ une demi-journée).**
Un `keepAlive` borné dans le temps sur les 35 providers : revenir sur un écran
dans les N minutes devient instantané, zéro requête. ~15 lignes d'aide
partagée + 35 appels d'une ligne.

> 🩸 **NE JAMAIS LIVRER SEUL.** Quatre de ces providers ne sont **jamais**
> invalidés après une écriture : `licencesDuGroupeProvider`,
> `institutionTypesProvider`, `comptesAdminParGroupeProvider`,
> `adminRattachementProvider`. Ils sont justes **parce qu'**ils sont froids.
> Les mettre en cache sans ajouter l'invalidation crée un défaut pire que
> celui qu'on corrige : on crée une licence et elle n'apparaît pas.
> Niveau 1 = cache **+** invalidations manquantes, dans le même lot.

**Niveau 2 — afficher avant de charger (≈ un jour).**
Persister la dernière charge utile réussie ; à l'ouverture, l'afficher
immédiatement avec « mis à jour il y a 3 min », rafraîchir en fond, remplacer
à l'arrivée. C'est le *stale-while-revalidate* des grandes plateformes.

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

**Niveaux 1 et 2 NON livrés, délibérément.** Le niveau 1 touche 35 chemins de
données et son mode de défaillance est « vous écrivez et vous ne voyez pas » —
précisément ce qui ne doit pas arriver devant un ministre, ni sur les cinq
premières écoles. À faire au calme, cache **et** invalidations dans le même lot.
