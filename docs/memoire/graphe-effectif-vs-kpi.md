# ⚠️ Un graphe et un KPI sur la même page doivent dire le même nombre

`effectifEvolutionProvider` (page Élèves) traçait une courbe qui finissait **au-dessus**
de la carte « Effectif » posée juste au-dessus d'elle. Trois causes, toutes du même
genre : la requête du graphe n'avait pas reçu les filtres de la requête de la liste.

## Les trois filtres qui manquaient

1. **`COALESCE(s.is_active, 1) <> 0`.** `deactivateStudent` met `students.is_active = 0`
   SANS toucher au statut de l'inscription — à dessein : une sortie de classe exige un
   motif normalisé (déperdition scolaire) qu'une désactivation administrative n'a pas.
   Sans ce filtre, l'élève disparaît de la liste mais reste compté ailleurs.
   ⚠️ **Le même piège existait sur l'effectif des classes** (`class_provider.dart`, déjà
   corrigé et commenté là-bas) — c'est un piège récurrent, pas un accident.
2. **`classScopeClause(ref, 'eleves', column: 'ce.class_id')`.** Un enseignant restreint
   à `own_classes` lisait la courbe de l'école entière sous ses propres KPI restreints.
3. **`permissionsLoaded(ref)`.** Publier avant la lecture du profil d'accès.

## Et le quatrième défaut, d'affichage

`GROUP BY mois` ne rend que les mois où quelque chose s'est passé. Sur un axe
**catégoriel**, un mois creux n'existe même pas comme espace : la pause d'octobre se
lisait comme une reprise immédiate. Le remplissage vit dans
`construireRythmeInscriptions()` (`inscriptions_rythme_provider.dart`), désormais
partagé par les deux graphes — avec ses tests.

## Réflexe

> Quand un graphe et un compteur voisinent, ce sont **deux requêtes**. Recopier les
> filtres de l'une dans l'autre n'est pas optionnel : l'écart ne lève aucune erreur, il
> s'affiche.

Voir aussi [[ecrans-jumeaux-guichet-registre]].
