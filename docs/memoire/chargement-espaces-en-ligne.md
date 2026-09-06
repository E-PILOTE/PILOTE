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

| Écran | Requêtes réseau par ouverture |
|---|---|
| Économie & licences | **13** |
| Abonnement du groupe | 10 |
| Tableau de bord fondateur | 10 |
| Frais de scolarité | 9 |
| Tableau de bord groupe | 8 |

Sur une liaison congolaise à 300–800 ms d'aller-retour, treize requêtes font
**4 à 10 secondes d'attente, à chaque visite**.

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

**Niveau 3 — réduire le nombre d'allers-retours.**
Treize requêtes pour un écran est le coût de fond. Plusieurs peuvent devenir
une seule RPC rendant un JSON. Chantier plus lourd, gain le plus fort.

## ⚠️ La règle qui encadre tout cache ici

Ces écrans portent de l'**argent**, des **quotas** et des **licences**. Un
chiffre en cache affiché comme un fait est exactement le défaut retiré les
2026-09-05/06 (cf. [[escalade-privileges-profiles]] pour la même famille de
silence). **Un cache doit DIRE son âge.** « Mis à jour il y a 3 min » n'est pas
un ornement : c'est ce qui le rend honnête. Et jamais de cache muet sur un
chiffre qui déclenche une action.

## Décision du 2026-09-06

**Rien livré ce soir.** Le niveau 1 touche 35 chemins de données et son mode de
défaillance est « vous écrivez et vous ne voyez pas » — précisément ce qui ne
doit pas arriver devant un ministre. À faire au calme après la présentation.
