# Organisation des modules — la chaîne METP

**Date** : 2026-07-17 · **Révisé** : 2026-07-17 (v2) · **Statut** : organisation décidée (aucun code)
**Cadre** : cf. `2026-07-17-positionnement-ministeres-25-aout.md` (v2) et `2026-07-17-dossiers-examens-metp.md`.

> **⚠️ Réécrit.** La v1 contenait trois erreurs de ma main :
> 1. **« La demande manuscrite pré-remplie »** érigée en fonctionnalité phare → **abandonnée**
>    (non attestée ; une demande imprimée n'est pas manuscrite).
> 2. **Un module `ateliers`** avec sa propre table → aurait **dupliqué `rooms`** et rendu la
>    détection de conflits aveugle (§4).
> 3. **« Un lot de 50 traverse les classes »** → **faux**. Un lot est **dans** une classe.

---

## 1. Le constat qui commande tout

Vérification en base des 14 écoles METP :

| Ce qu'elles contiennent | Classes | Élèves |
|---|---|---|
| Collège **général** (6e→3e, sans filière) | 32 | 325 |
| Lycée séries **A / C / D** (= enseignement **général**) | 5 | 1 |
| Primaire | 6 | 1 |
| **Formation professionnelle** | **0** | **0** |

Les filières techniques existent dans le référentiel. **Aucune classe ne les utilise.** Aucun
atelier, aucun équipement en base.

**E-PILOTE est aujourd'hui un outil d'enseignement général, sous une étiquette METP.** Le montrer
tel quel au ministre le 25 août serait contre-productif — il verrait ce qu'il a déjà.

---

## 2. La hiérarchie réelle — corrigée

**Établi par l'utilisateur (DSIC)** :

```
niveau (Terminale, Seconde…) ▸ classe (porte la filière : « Seconde A ») ▸ lot (~50)
```

Un **lot est à l'intérieur d'une classe**. La filière est **portée par la classe**.

**Conséquence : notre axe `cycle ▸ niveau ▸ classe` est le bon.** Le `ScopeDrilldownPanel` et
l'écran de session n'ont pas à être refondus. Un lot est un simple découpage de la classe à 50 —
et comme la classe détermine la filière, le lot est homogène par construction.

*(La v1 affirmait qu'un lot traversait les classes et concluait qu'il fallait changer l'axe de
tout le module. C'était une sur-interprétation de « groupés par filière ». J'allais casser ce qui
marche.)*

---

## 3. La chaîne METP réelle — et où nous sommes

| Étape | Réalité METP | Module E-PILOTE | État |
|---|---|---|---|
| Concours d'entrée collège technique | concours, **≤ 16 ans**, niveau **5e** | `examens` (kind=concours) | ⚠️ concours présent, règle d'âge/niveau absente |
| Filière professionnelle | 3 ans (a1→a3) | `niveaux` / `classes` | ⚠️ référentiel prêt, **0 classe** |
| Cours théoriques | — | `emploi-du-temps`, `programmes`, `notes` | ✅ |
| **Atelier / plateau technique** | **le cœur du métier** | — | ❌ (§4) |
| **Équipements** (machines, outillage) | une filière soudure sans poste à souder ne forme personne | — | ❌ |
| Stage en entreprise | **attestation obligatoire au dossier de bac** | `stages` | ⚠️ **lecture seule — 0 écriture** |
| Dossier d'examen | pièces + attestation, vérifiées **école ET DEC** | `examens` | ⚠️ modèle à corriger |
| **Saisie à la DEC** | l'école **retape tout à la main** | — | ❌ **le vrai sujet** |
| **Dépôt physique** | les dossiers papier partent à la DEC | — | ❌ transmission absente |
| Épreuves **pratiques** | distinctes des écrits | `exam_sessions.practical_*` | ⚠️ champ présent, rien pour organiser |
| Insertion | — | — | ❌ |

---

## 4. Les ateliers — la correction

**L'atelier existe déjà.** `0015_timetable_rooms.sql` crée `rooms` avec `room_type`, dont le
catalogue prévu contient explicitement **`atelier`**. Table déjà synchronisée offline
(`powersync_schema.dart:469`).

**Un module `ateliers` avec sa propre table aurait été une faute grave**, et pas seulement une
redondance : l'emploi du temps détecte les conflits **par égalité de `room_id`** — c'est écrit
dans 0015, le champ texte libre causait des « conflits ratés ». Un atelier hors de `rooms` rend
l'EDT **aveugle** : deux classes au même poste à souder, personne ne le voit.

**Décision** : `ateliers` **enrichit `rooms`**, ne la double pas. La salle reste l'objet physique
que l'EDT réserve ; l'atelier est sa dimension pédagogique (filière, postes, conformité).

**Et la capacité se dérive** — nombre d'équipements en état de marche, jamais saisie. Comme
`resolve_class_exam()` : la règle vit à un endroit.

### Le désaccord de fond avec le tronc

Trois hypothèses de l'enseignement général que le technique casse — **aucun module ne les
répare**, ce sont des extensions du tronc :

1. **La capacité, c'est des places assises.** En technique, c'est le **nombre de machines qui
   marchent**. 30 élèves en soudure avec 8 postes, ça forme 8 personnes à la fois.
2. **La classe est monolithique.** `timetable_slots` = *(class_id, subject_id, teacher_id,
   room_id)* — recherche de « demi-groupe », « rotation », « sous-groupe » : **zéro résultat**.
   En technique, la classe se **scinde** et **tourne** sur les plateaux.
3. **La note est écrite.** Le technique évalue un **geste**, et le stage est noté par un **tuteur
   d'entreprise** — un acteur qui n'est pas un utilisateur.

⚠️ Le point 2 touche un module livré et vérifié. **À traiter après le 25 août.**

---

## 5. L'organisation des modules

### FORMATION PROFESSIONNELLE

| Module | Rôle | Priorité |
|---|---|---|
| `stages` | Conventions, tuteurs, évaluation, **attestation** (pièce du dossier de bac) | ⚠️ **écrit à finir** |
| **`ateliers`** 🆕 | Plateau technique **adossé à `rooms`** : filière, postes, conformité | P2 |
| **`equipements`** 🆕 | Machines : affectation, état, maintenance | **P1** (la capacité en dépend) |
| `apprentissage` 🔜 | Public déscolarisé | P3 |
| `insertion` 🔜 | Devenir des diplômés | P4 |

**Pourquoi `equipements` avant `ateliers`** : sans machines, un atelier est une salle vide. La
capacité se dérive des équipements — l'ordre inverse produirait une coquille.

**Pourquoi les deux séparés** : l'atelier est un **lieu** (filière, capacité, emploi du temps) ;
l'équipement est un **bien** (il s'achète, se casse, se déplace, s'amortit). Les fusionner
interdirait de suivre une machine déplacée d'un atelier à l'autre — le quotidien.

**Pas de catégorie « METP ».** Le METP n'est pas une autre école : c'est la **même** école avec
une branche technique. Une catégorie parallèle dupliquerait Scolarité, Évaluation et EDT pour 14
tenants sur 24 — deux troncs à maintenir à vie.

### EXAMENS & CERTIFICATION — un module, plusieurs sections

Pas de nouveau module. `examens` absorbe : candidatures ✅ · **dossier par pièces** 🆕 (modèle
corrigé) · **transmissions** 🆕 · résultats **entrants** 🆕.

**Pourquoi pas de module « Transmissions »** : ce n'est pas un domaine, c'est un **acte** du
module Examens. Un catalogue qui gonfle à chaque concept est illisible — et invendable.

---

## 6. Ce qui gagne la salle le 25 août (v2)

La v1 misait sur la demande manuscrite. **Abandonné.**

> **Ce qui gagne, c'est la ressaisie supprimée et le nom juste.**

L'école détient l'identité, saisie une fois depuis l'acte de naissance. Un agent la **retape à la
main** dans l'application DEC — 6 867 candidats pour le seul BET. Ce qui est tapé **devient le
diplôme**.

Ça ne se raconte pas, ça se **montre** : la liste prête, ordonnée comme leur formulaire, découpée
en lots de 50 — et la demande d'interface (`2026-07-17-spec-api-dec.md`) qui supprime la frappe.

---

## 7. Ordre d'exécution jusqu'au 25 août

| # | Lot | Pourquoi | Sans quoi |
|---|---|---|---|
| 1 | **Examens — les 2 actions internes** (retrait, dossier) | Providers écrits, **boutons absents** | Le module inscrit et ne sait rien faire d'autre |
| 2 | **Stages — les écritures** (entreprise, convention, **attestation**) | L'attestation est une **pièce du dossier de bac** | L'alerte « dossier bloqué » s'affiche sans solution |
| 3 | **Données METP réelles** : classes de filières pro, avec élèves | La démo doit montrer du **technique** | Le ministre voit de l'enseignement général |
| 4 | **`local_ref` + `transmissions`** + liste ordonnée par lots de 50 | Feuille de frappe **et** bordereau d'expédition, figés | Aucun dépôt traçable — **rétroactivement irréparable** |
| 5 | **`equipements`** | Le cœur du métier technique | E-PILOTE reste un outil généraliste repeint |
| 6 | **Chaînage** résultat → `graduated` / orientation | Le « mise en mouvement » demandé | Les modules ne se parlent pas |

**Hors périmètre assumé** : `ateliers`, groupes/rotation dans l'EDT, apprentissage, insertion,
statistiques nationales, candidats libres (ils déposent en direction départementale — pas notre
sujet).

---

## 8. État réel des deux modules (mesuré, pas supposé)

**Examens** — 5 actions d'écriture existent, **1 seule est câblée** :

| Action | Provider | Bouton |
|---|---|---|
| Inscrire | ✅ | ✅ |
| Retirer | ✅ | ❌ |
| Dossier | ✅ | ❌ |
| Soumettre | ✅ | ❌ ← exige `transmissions` |
| Résultat | ✅ | ❌ ← exige source + date (donnée **entrante**) |

⚠️ **Câbler `submitDossier` et `setResult` tels quels graverait dans l'interface le modèle que la
recherche a invalidé** : un résultat qu'on *produit* au lieu de le *recevoir*, un dépôt sans
preuve.

**Stages** — 473 lignes, **zéro écriture** (`grep` sur `db.execute` : aucun résultat).

---

## 9. Ce que je ne sais toujours pas

- **Photos et badges** : téléversés dans l'appli DEC ou uniquement au dossier papier ?
- **Attestation de stage** : due pour BEP / BTF / CAP, ou seulement pour le bac ?
- **Diplôme antérieur au bac** : « **au moins** » ou « **moins de** » 3 ans ? (sources contradictoires)
- **Les épreuves pratiques** : dans les ateliers des établissements ? Si oui, `ateliers` devient
  aussi un outil d'examen — et le sujet change de dimension.
- **Le formulaire de saisie de la DEC** : une capture, et l'export cesse d'être « raisonnable »
  pour devenir exact.
