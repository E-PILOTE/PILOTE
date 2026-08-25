---
name: motifs-de-sortie-eleve
description: "Nomenclature fermée des sorties d'élève (mig 0082) — abandon économique et abandon familial SÉPARÉS ; liste à faire valider par le MEPSA/METP"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T15:09:27.317Z
---

# Pourquoi un élève sort (migration 0082, 2026-08-03)

`class_enrollments.withdrawal_reason` était du **texte libre**, et le dialogue
de sortie écrivait « Radiation » quand l'agent ne saisissait rien. Aucun
agrégat national possible — alors que c'est précisément le chiffre qu'un
ministère publie.

**Désormais** : `withdrawal_motif`, liste fermée par contrainte `CHECK`, **à
côté** du texte libre. La catégorie sert à compter, le commentaire à
comprendre un cas particulier. L'un ne remplace pas l'autre.

## Les onze motifs

*Sorties déclarées* : `transfert`, `demenagement`
*Déperdition* : `abandon_economique`, `abandon_familial`, `abandon_distance`,
`maladie`, `deces`
*Prononcée par l'école* : `exclusion`
*Fin de parcours* : `fin_de_scolarite`
*Ce que l'école ignore* : `non_reinscrit`, `autre`

⚠️ **`abandon_economique` et `abandon_familial` sont séparés à dessein.** Ils
n'appellent pas la même politique publique, et le second (mariage, grossesse,
charge familiale) touche massivement les filles. D'où la vue
`v_sorties_par_motif`, qui rend la **part de filles par motif**.

## Décisions techniques

- **CHECK et non type énuméré** : le ministère ajustera la liste ; amender un
  type dont dépendent vues et fonctions coûte cher.
- **Motif OBLIGATOIRE** aux deux points de sortie (fiche élève, pipeline
  d'inscriptions) — bouton inactif tant qu'il n'est pas choisi.
- **Reprise de l'existant** : on ne devine pas. Seul `transferred` →
  `transfert` et `graduated` → `fin_de_scolarite` ; le reste devient `autre`,
  qui est la vérité.

⚠️ **Source unique côté app** : `lib/core/utils/sortie_motif.dart`, à tenir
identique à la contrainte SQL — un motif accepté ici et refusé en base ferait
abandonner le **lot PowerSync entier** ([[type-local-suit-type-serveur]]).
Même règle que [[bareme-mention-source-unique]] et
[[ine-identifiant-national-eleve]].

## ✅ CETTE LISTE FAIT FOI (user, 2026-08-03)

Le Congo n'avait aucun système : il n'existe aucune nomenclature antérieure à
respecter. Le user est le ministère ([[user-fonctionnaire-dsic-metp]]) et a
tranché — **cette liste EST la référence nationale**. Ne plus la présenter
comme provisoire. La modifier = une migration touchant la contrainte SQL **et**
le fichier Dart, sur décision du user seul.

## Ce qui reste ouvert

Le **non-réinscrit** n'est pas détecté automatiquement : le motif existe, mais
rien ne repère l'élève de l'an dernier qui n'a pas de ligne cette année. Il
reste `active` sur l'année passée — ni sorti, ni présent. Voir
[[deploiement-national-octobre]], rupture R3.

L'**exclusion disciplinaire** ne remonte toujours pas depuis
`discipline_incidents` (rupture R4).

Liens : [[deploiement-national-octobre]] · [[ine-identifiant-national-eleve]] ·
[[inscription-module-logique]]
