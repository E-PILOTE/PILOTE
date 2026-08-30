# Le système éducatif de la République du Congo — référentiel de la plateforme

> **La République du Congo est le seul référentiel.** Aucune architecture
> scolaire étrangère ne sert de modèle. Ce document dit ce que la plateforme
> affirme, sur quelle source, et ce qu'elle refuse encore d'affirmer.

Migrations : `0151` (structure), `0152` (parcours corrigés sur source).

---

## 1. La distinction qui gouverne tout

| Élément | Nature | Où il vit |
|---|---|---|
| CET, lycée technique, CEG, centre de métiers | **Établissement** | `institution_types` |
| Filière, série, spécialité | **Domaine de formation** | `education_programs` |
| CAP, BEP, BET, BTF, CQP, BT, BEPC, Bac | **Diplôme** | `national_exams` |
| Poursuite d'études | **Passerelle** | `education_pathways` |

**CET ≠ CAP. CET ≠ BET. FILIÈRE ≠ DIPLÔME.**

Confondre les deux premiers rend impossible toute question sensée : *« combien
d'élèves en CET ? »* n'a pas de réponse si CET est rangé comme un diplôme.

---

## 2. Ce que la plateforme n'a PAS créé, et pourquoi

Trois tables demandées existaient déjà sous un autre nom. Les dupliquer aurait
répété la faute du barème des mentions — quatre exemplaires, dont un donnait
« Passable » pour 8/20.

- **`diplomas` → `national_exams`.** Elle portait déjà CEPE, BEPC, BET, BEP,
  BTF, CAP, CQP, BAC_G, BAC, BTS, CFEEN, DCAF, DEMA, DECS, avec `tutelle`,
  `cycle_code` et `kind`. Le BET y figurait **déjà** au cycle `college` sous
  tutelle `metp`. `0152` y ajoute le **BT** (Brevet de Technicien), qui
  manquait.
- **`education_sectors` → `tutelle_enum`.** Au Congo le secteur se lit sur la
  tutelle : `mepsa` = enseignement général, `metp` = technique et
  professionnel. Un troisième vocabulaire pour la même idée n'aurait ajouté que
  des occasions de désaccord.
  ⚠️ Le Congo compte **trois** ministères de l'éducation — le troisième étant
  l'Enseignement supérieur, hors périmètre d'une plateforme scolaire.
- **`institution_types` → créée.** C'était le vrai manque : `schools.school_type`
  vaut `public`/`prive`, c'est le **statut juridique**, pas le type. Rien ne
  permettait de dire d'une école qu'elle est un CET.

---

## 3. Les parcours, tels qu'ils sont

```
CEPE
 ├─→ 6ème générale (CEG) ──────────→ BEPC ─┬─→ 2nde générale (Lycée) → BAC général
 │                                          └─→ Lycée technique (LET) → BAC technique
 └─→ Centre de métiers (2 ans, attestation)
              └─→ CET (2 à 3 ans) → BET ──→ Lycée technique (3 ans) → BAC technique
                                                                          └─→ BTS / DUT
```

**Points qu'une lecture rapide manque :**

- **On n'entre pas en CET au sortir du CM2.** Le CET s'intègre *après* un centre
  de métiers, ou pour qui a terminé la **5ème** du secondaire général. Proposer
  l'entrée en CET à un sortant de CM2 ferait rejeter son dossier.
- **Le centre de métiers ne délivre pas de diplôme.** Deux ans, sanctionnés le
  plus souvent par une simple **attestation**. Ne jamais le présenter comme une
  qualification finale.
- **Le BEPC ouvre aussi le lycée technique.** C'est la passerelle du général
  vers le technique à la fin du premier cycle — la plus utile à l'orientation.
- **Le CAP ouvre l'emploi autant que la poursuite.** C'est une qualification
  professionnelle, pas une étape obligée.

---

## 4. ⚠️ Ce qui est EN VIGUEUR et ce qui est un PROJET

Chaque ligne du référentiel porte un `statut` :

| statut | sens |
|---|---|
| `en_vigueur` | texte promulgué et applicable |
| `projet_reforme` | adopté en Conseil des ministres, **non promulgué** |
| `historique` | abrogé, conservé pour lire les archives |
| `a_verifier` | saisi sans source officielle confirmée |

**Le cas qui a motivé cette colonne.** Les lycées d'enseignement technique sont
ouverts aux titulaires d'un BET : c'est le régime **en vigueur**. Le projet de
loi examiné en Conseil des ministres le **20 janvier 2026** en ferait une
condition **nécessaire** de candidature au baccalauréat technique — et il a été
transmis au Parlement, non promulgué.

Le référentiel porte donc **deux lignes distinctes** : la passerelle
(`en_vigueur`) et l'exigence (`projet_reforme`, `obligatoire = true`).

> **Ne jamais bloquer la candidature d'un élève sur une règle `projet_reforme`.**

⚠️ Ne pas s'arrêter à janvier 2026 : consulter les Conseils des ministres
postérieurs avant de considérer une règle comme figée.

---

## 5. ⚠️ La nomenclature des filières n'est PAS complète

Les filières sont fixées par **arrêté du ministre** chargé de l'enseignement
technique et professionnel. Les sources publiques donnent leur ordre de
grandeur — **27 séries technologiques** au baccalauréat, **18 options** de
brevets techniques et professionnels, **9 séries professionnelles**, **21
options spécialisées** — mais les intitulés exacts n'ont pas pu être récupérés
au 2026-08-30 (PDF du ministère en 404).

**Aucune filière n'a donc été inventée.** Les filières existantes sont
conservées et marquées `a_verifier` par défaut. Seules celles que les sources
permettent d'établir sans deviner sont passées `en_vigueur` :

| filière | établissement | prépare |
|---|---|---|
| Enseignement Général | CEG | BEPC |
| Enseignement Technique | **CET** | **BET** |
| Séries A, C, D | Lycée général | BAC général |
| Séries E, F1–F7, G1–G3 | Lycée technique | BAC technique |

Le référentiel dit lui-même ce qu'il n'a pas vérifié, plutôt que de présenter
une invention comme une nomenclature d'État.

---

## 5 bis. Groupe, école, ministère — qui porte quoi

**La tutelle appartient au GROUPE.** L'école en hérite et ne peut pas la
contredire — exactement comme `group_type` (public / privé), que l'écran de
création d'école n'offre déjà plus au choix.

Trois faits l'établissent :

- **Chaque ministère agrée ses propres établissements privés**, par sa propre
  commission. Le MEPSA a examiné **1 192 dossiers** d'enseignement général
  (783 en agrément provisoire, 409 en définitif) ; le METP en a examiné **108**
  puis **151** pour le technique et professionnel. Un établissement privé
  relève d'UNE commission.
- **Les groupes privés congolais couvrent des NIVEAUX, pas des ministères** —
  « de la maternelle au lycée ». Aucun contre-exemple trouvé.
- **Sur nos propres données** : les 7 groupes ont chacun une seule tutelle.
  Zéro groupe mixte.

`schools.tutelle` **n'est pas supprimée** : ce serait la faute de la migration
0146 — un poste en retard l'enverrait encore, PostgREST répondrait 42703, non
reconnu comme fatal, et la synchro de ce poste mourrait en silence. Elle
devient une **copie dénormalisée**, tenue par déclencheur depuis le groupe.

⚠️ `school_groups.tutelle` reste **nullable** : la passer NOT NULL maintenant
casserait la création de groupe depuis le build déployé, qui ne l'envoie pas
(23502, famille fatale). Elle le deviendra une fois le build publié ET adopté.

### ⚠️ L'agrément est une donnée d'ÉTABLISSEMENT, et elle manque

Le MEPSA accorde **trois ans** aux établissements privés pour se mettre en
conformité, après quoi **les inscriptions aux examens d'État seront
conditionnées à un agrément valide**.

La plateforme ne stocke aujourd'hui aucun agrément. Pour ses clients privés —
et ils sont la majorité du marché — il faudra un numéro d'agrément, son type
(provisoire / définitif), sa date, et son ministère émetteur. Sans quoi une
école découvrira le problème au moment d'inscrire ses élèves à l'examen.

## 6. Ce qui reste à faire

- [ ] **Charger la nomenclature officielle** des filières depuis l'arrêté
      ministériel, et passer les lignes de `a_verifier` à `en_vigueur`.
- [ ] **Typer les 37 écoles** : `schools.institution_type_id` est volontairement
      vide. Deviner d'après le nom (« CEG de Moungali ») marcherait pour la
      plupart et se tromperait pour quelques-unes — et une école mal typée
      remonterait ses effectifs dans la mauvaise colonne d'un état ministériel.
      C'est à l'admin groupe de le déclarer.
- [ ] **Écrans** : tutelle à la création du GROUPE ; sélection en cascade
      secteur → cycle → type d'établissement → filière → diplôme ; passerelles
      dans l'orientation.
- [ ] **`school_groups.tutelle` NOT NULL**, après publication ET adoption du
      build qui la renseigne.
- [ ] **L'agrément des établissements privés** — numéro, type, date, ministère.
      Échéance réglementaire : trois ans, puis blocage des inscriptions aux
      examens d'État.
- [ ] **Vérifier les Conseils des ministres postérieurs** à janvier 2026.

---

## 7. Sources

| # | Source | Usage |
|---|---|---|
| 1 | [Ministère de l'Enseignement technique et professionnel](https://www.enseignement-technique.gouv.cg/) | **Prioritaire.** Filières, établissements, formations, examens, diplômes, nomenclature. |
| 2 | [Gouvernement de la République du Congo](https://gouvernement.cg/) | Lois, projets de loi, décrets, Conseils des ministres. |
| 3 | [Conseil des ministres du 20 janvier 2026](https://gouvernement.cg/compte-rendu-du-conseil-des-ministres-du-20-janvier-2026/) | Projet de réforme — distinguer du régime en vigueur. |
| 4 | [Archives des Conseils des ministres](https://gouvernement.cg/category/compte-rendu-du-conseil-des-ministres/) | Vérifier les décisions postérieures à janvier 2026. |
| 5 | [France Éducation International — « Congo, système éducatif en bref » (juillet 2025)](https://www.france-education-international.fr/system/files/medias/fichiers/2025/08/Congo.pdf) | **Durées et conditions d'entrée.** Source de la migration `0152`. |
| 6 | [France Éducation International — fiche Congo](https://www.france-education-international.fr/enic-naric-bdd/127) | Comparabilité des diplômes. |
| 7 | Décret n° 2017-149 du 10 mai 2017 (JO N° 20-2017) | Lycées techniques : accès, organisation, fonctionnement. |
| 8 | Décret relatif aux établissements de l'enseignement technique | CET = établissement du **premier cycle** ; ouverture par arrêté ministériel. |

⚠️ **La source 5 est une synthèse, pas un texte congolais.** Ses durées et
conditions décrivent le régime appliqué, mais une règle opposable à une famille
doit être confirmée sur le texte congolais lui-même. C'est à cela que sert la
colonne `source` de chaque ligne : elle dit d'où vient ce qu'on affirme.
