---
name: abonnement-licence-de-tutelle
description: "Tarif ministère = DEUX lignes (exploitant sur grille + tutelle forfaitaire) ; le SYSTÈME est livré (mig 0160) ; les MONTANTS restent une recommandation non validée"
metadata: 
  node_type: memory
  type: project
---

**Statut au 2026-08-31 :**
- **le SYSTÈME est livré** — table `tutelle_licences` (migration 0160), montants
  LIBRES et modifiables, écran `/super/economie` ;
- **les MONTANTS ci-dessous restent une recommandation non validée** par
  l'utilisateur.

⚠️ **La licence NE COMMANDE AUCUN ACCÈS.** La vue de tutelle dépend de
`school_groups.administre_referentiel_national` (migration 0155), pas d'elle.
Une licence échue ne coupe donc pas un ministère : on ne ferme pas l'État pour
un mandat en retard, et un logiciel qui se venge d'un impayé perd le client ET
le marché.

**Trois montants, pas un** (`montant_xaf`, `avance_xaf`, `montant_regle_xaf`) :
un marché public se négocie, se révise par avenant et se règle en tranches.

## Le défaut de la grille — CORRIGÉ le 2026-08-31

La falaise Pro→Institutionnel (**×11,4 à la 11ᵉ école**) a été supprimée par la
migration 0159 : le prix suit désormais le nombre d'écoles, par tranches
dégressives. Détail dans [[tarif-par-ecole-et-couts-reels]].

**Conséquence sur ce document** : la ligne « exploitant » d'un ministère ne
coûte plus les 9 M/an que j'estimais, mais ce que dit la grille —
**MEPSA 170 000 XAF/mois (2,04 M/an)** pour ses 14 écoles, **METP 154 000/mois
(1,85 M/an)** pour ses 12. Mesuré en base.

## La règle : deux lignes, jamais une

Un ministère porte deux casquettes (cf. `docs/SYSTEME_EDUCATIF_CONGOLAIS.md` § 5 ter,
et [[abonnement-referentiel-tarifaire]] pour la grille). Elles s'achètent séparément :

| ligne | ce qui est acheté | assiette |
|---|---|---|
| **Exploitant** | ses propres écoles, qui saisissent vraiment | grille publique, comme tout le monde |
| **Tutelle** | la vue + l'écriture sur TOUS les groupes de sa tutelle | forfait annuel négocié |

Les fusionner est la faute à ne pas commettre : si le ministère paie pour tout,
plus aucune école privée ne paiera jamais, et E-PILOTE devient une société à un
seul client — un client qui change de ministre.

## Le montant recommandé

| | exploitant (grille, mesuré) | licence de tutelle (proposé) | total / an |
|---|---|---|---|
| **METP** (12 écoles, ~150-250 étab. sous tutelle) | 1,85 M | **18 M** | **≈ 19,9 M XAF** (~30 000 €) |
| **MEPSA** (14 écoles, ~2 500-3 500 étab. sous tutelle) | 2,04 M | **48 M** | **≈ 50 M XAF** (~76 000 €) |

⚠️ Les volumes d'établissements sous tutelle sont des ORDRES DE GRANDEUR déduits
du web (Brazzaville seule : ~505 primaires + 90 secondaires + 17 techniques).
**À faire confirmer par l'utilisateur, qui est à la DSIC du METP** — sa parole
prime sur mes recherches ([[user-fonctionnaire-dsic-metp]]).

**Pilote payant préalable : 1 département, 6 mois, 12 M XAF, déductible de la
première annuité.** Un pilote gratuit n'est jamais évalué et ne se transforme pas :
il n'a ni bordereau, ni responsable, ni rapport.

## Pourquoi le forfait de tutelle est FIXE

Il ne varie pas avec le nombre d'écoles effectivement raccordées. Délibéré : une
licence indexée sur l'adoption paierait le ministère pour freiner l'adoption.
L'assiette est le périmètre de tutelle — un fait de l'État, pas un résultat
commercial.

## Les conditions qui comptent plus que le prix

- **Annuité payée d'avance, calée sur l'exercice budgétaire (janv.-déc.)**, pas
  sur l'année scolaire. Une licence à cheval sur deux exercices se paie en retard.
- **Avance de démarrage 30 %** à la signature.
- **Jamais plus d'un tiers du chiffre d'affaires** sur les lignes publiques : la
  société doit survivre à 12 mois d'impayé de l'État.
- **Ne jamais accepter d'être payé par les abonnements des écoles.**
- **Réversibilité (export en format ouvert), pas le code source.**
- ⚠️ **Souveraineté des données** : Supabase `eu-central-2` = Zurich. Un
  ministère peut l'objecter à la signature. Décider AVANT, pas en réunion.
- ⚠️ **Ne pas fractionner** un marché pour passer sous un seuil : c'est ce qui
  fait annuler un contrat deux ans plus tard.

## Le point personnel, dit une fois

L'utilisateur est fonctionnaire à la DSIC du METP. Un contrat E-PILOTE–METP le
place des deux côtés. Cela ne l'interdit pas ; cela impose de le structurer
(déclaration d'intérêts, retrait de la chaîne de décision) ou de vendre d'abord
au privé et au MEPSA. Ne se rattrape pas après signature.
