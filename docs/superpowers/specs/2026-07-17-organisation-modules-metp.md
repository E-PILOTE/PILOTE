# Organisation des modules — la chaîne METP

**Date** : 2026-07-17 · **Statut** : organisation décidée (aucun code)
**Cadre** : le METP est la tête de pont (14 écoles sur 24 en base, encore au papier, aucun incumbent). cf. `2026-07-17-positionnement-ministeres-25-aout.md`.

---

## 1. Le constat qui commande tout

Vérification en base des 14 écoles METP :

| Ce qu'elles contiennent | Classes | Élèves |
|---|---|---|
| Collège **général** (6e→3e, sans filière) | 32 | 325 |
| Lycée séries **A / C / D** (= enseignement **général**) | 5 | 1 |
| Primaire | 6 | 1 |
| **Formation professionnelle** | **0** | **0** |

Les 20 filières techniques (soudure, mécanique, électricité, couture, hôtellerie, agriculture…) existent dans le référentiel. **Aucune classe ne les utilise.** Aucun atelier, aucun équipement, aucun apprenti en base.

**Conclusion sans détour : E-PILOTE est aujourd'hui un outil d'enseignement général, sous une étiquette METP.** Le montrer tel quel au ministre du METP le 25 août serait contre-productif — il verrait exactement ce qu'il a déjà.

---

## 2. La chaîne METP réelle — et où nous sommes

Le parcours d'un élève METP, tel qu'établi par les sources officielles :

```
CONCOURS D'ENTRÉE          FORMATION                    CERTIFICATION        INSERTION
(≤16 ans, après la 5e)  →  théorie + ATELIER + STAGE →  dossier → DEC →   →  emploi /
                                                         écrits + PRATIQUES   apprentissage
```

| Étape | Réalité METP | Module E-PILOTE | État |
|---|---|---|---|
| Concours d'entrée collège technique | concours, **≤ 16 ans**, niveau **5e** requis | `examens` (kind=concours) | ⚠️ le concours existe, pas la règle d'âge/niveau |
| Filière professionnelle | 20 filières, 3 ans (a1→a3) | `niveaux` / `classes` | ⚠️ référentiel prêt, **0 classe** |
| Cours théoriques | — | `emploi-du-temps`, `programmes`, `notes` | ✅ |
| **Atelier / plateau technique** | **le cœur du métier** | — | ❌ **rien** |
| **Équipements** (machines, outillage) | une filière soudure sans poste à souder ne forme personne | — | ❌ **rien** |
| Stage en entreprise | attestation **obligatoire** au dossier de bac | `stages` | ✅ livré |
| Dossier d'examen | **demande manuscrite** + pièces + attestation | `examens` | ⚠️ pas la demande manuscrite |
| Dépôt à la DEC | direction départementale ou établissement, **clôture 14/02 à 14h00** | — | ❌ **transmission absente** |
| Épreuves **pratiques** | 30 juin → 4 juillet, distinctes des écrits | `exam_sessions.practical_*` | ⚠️ champ présent, rien pour organiser |
| Insertion | — | — | ❌ |

---

## 3. Deux angles morts du modèle, pas seulement des modules manquants

### 3.1 Le public non scolarisé

L'ETFP s'adresse aux jeunes et adultes « scolarisés, **déscolarisés**, **non scolarisés** », et la note METP prévoit explicitement les **candidats libres** (qui s'inscrivent à la direction départementale, pas via un établissement).

Or notre modèle est : `students` → `class_enrollments` → `classes`. **Un candidat libre ou un apprenti n'a pas de classe.** Il ne peut pas exister chez nous.

Ce n'est pas un module manquant, c'est une **hypothèse trop étroite**. Un candidat doit pouvoir exister **sans classe** — `exam_candidates.class_id` est d'ailleurs déjà nullable ; c'est `class_enrollments` qui bloque.

### 3.2 Les cinq catégories d'établissements

L'ETFP couvre : collèges/lycées techniques · supérieur · écoles spécialisées · **centres de formation et d'apprentissage** · **formation continue**. Notre `education_cycles` s'arrête à `formation_pro`. L'apprentissage et la formation continue n'ont pas de place.

**Décision** : ne pas traiter le supérieur (hors périmètre : c'est un autre ministère). Traiter l'apprentissage **plus tard**, mais ne pas se rendre incapable de l'ajouter (d'où le point 3.1 : découpler candidat et classe).

---

## 4. L'organisation des modules — décision

### FORMATION PROFESSIONNELLE — le pack METP

C'est la catégorie créée le 2026-07-17. Elle ne contient qu'un module ; voilà sa cible :

| Module | Rôle | Priorité |
|---|---|---|
| `stages` ✅ | Conventions, tuteurs, évaluation, **attestation** (pièce du dossier de bac) | livré |
| **`ateliers`** 🆕 | Plateaux techniques : le lieu, sa filière, sa capacité, ses créneaux, sa conformité sécurité | **P1 — le cœur** |
| **`equipements`** 🆕 | Machines et outillage : affectation à un atelier, état, maintenance, mise hors service | **P1** |
| `apprentissage` 🔜 | Apprentis et alternance — le public déscolarisé | P3 |
| `insertion` 🔜 | Devenir des diplômés (l'indicateur qui intéresse un ministre) | P4 |

**Pourquoi `ateliers` et `equipements` séparés ?** L'atelier est un **lieu de formation** (il a une filière, une capacité, un emploi du temps) ; l'équipement est un **bien** (il s'achète, se casse, se répare, s'amortit). Les fusionner interdirait de suivre une machine déplacée d'un atelier à l'autre — or c'est le quotidien. Et `equipements` resservira à l'inventaire général plus tard.

**Pourquoi c'est le bon pack commercial** : une école technique a besoin des deux, plus `stages`, plus `examens`. Tous en `pro`/`institutionnel`. C'est cohérent avec la règle déjà posée : catégorie → module → plan.

### EXAMENS & CERTIFICATION — un seul module, plusieurs sections

Pas de nouveau module. `examens` absorbe :
- candidatures et dossiers ✅
- **demande manuscrite pré-remplie** 🆕 (§5)
- **transmissions / dépôts** 🆕 (l'objet immuable décidé dans `architecture-transmission-dec.md`)
- résultats (entrants) ✅

**Pourquoi ne pas créer un module « Transmissions »** : ce n'est pas un domaine, c'est un **acte** du module Examens. Un catalogue qui gonfle à chaque concept est un catalogue illisible — et invendable.

---

## 5. La fonctionnalité qui gagne la salle le 25 août

> **La demande manuscrite pré-remplie.**

Le METP exige, pour chaque candidat, *« une demande manuscrite adressée au Directeur des examens et concours techniques et professionnels, précisant la spécialité ou l'option »*. Aujourd'hui : l'élève écrit à la main, l'école empile, le proviseur porte les registres avant le 14 février à 14 h.

E-PILOTE peut sortir, en un clic et pour une classe entière : la fiche pré-remplie (identité, filière, spécialité, diplôme visé), prête à signer, **plus** le bordereau de dépôt, **plus** la liste des candidats.

**Ce n'est pas la fonctionnalité la plus élégante que j'aie conçue. C'est la plus vendeuse** : elle prend le geste que le ministre connaît — la pile de demandes manuscrites — et le remplace sous ses yeux. Aucun concurrent en ligne ne le fait, parce qu'aucun ne s'intéresse au METP.

---

## 6. Ordre d'exécution jusqu'au 25 août (5 semaines)

| # | Lot | Pourquoi | Sans quoi |
|---|---|---|---|
| 1 | **Données METP réelles** : classes de filières pro dans 2-3 écoles, avec élèves | La démo doit montrer du **technique** | Le ministre voit de l'enseignement général |
| 2 | **`ateliers` + `equipements`** | Le cœur du métier technique | E-PILOTE reste un outil généraliste repeint |
| 3 | **Demande manuscrite + bordereau + liste** (via `transmissions`) | Le moment « waouh » (§5) | On raconte, on ne montre pas |
| 4 | **Chaînage stage → dossier de bac** | Déjà à moitié fait (l'alerte existe) | La démo ne relie pas les modules |
| 5 | Règles concours d'entrée (≤16 ans, niveau 5e) | Complète la chaîne en amont | Trou visible au début du parcours |
| 6 | Candidat sans classe (candidats libres) | Angle mort du modèle (§3.1) | Question embarrassante en séance |
| 7 | Espace ministère : consolidation des dépôts | Le ministre veut voir **ses 14 écoles** | Pas de vue « ministre » |

**Hors périmètre assumé avant le 25 août** : apprentissage, insertion, API DEC, statistiques nationales.

---

## 7. Ce que je ne sais toujours pas

- **Le formulaire réel de la demande manuscrite** : existe-t-il un modèle imposé, ou est-ce du texte libre ? Cela décide si nous pré-remplissons un **modèle officiel** ou un document maison. **Une photo d'une demande de l'an dernier suffit** — c'est le point le plus rentable à obtenir.
- **Le bordereau de dépôt** : la DEC en délivre-t-elle un ? Sous quelle forme ?
- **Les filières réellement enseignées** dans vos 14 écoles METP : nos 20 filières viennent d'un référentiel, pas d'un relevé de terrain.
- **Les épreuves pratiques** : organisées par la DEC dans les centres, ou dans les ateliers des établissements ? Si c'est le second, le module `ateliers` devient aussi un outil d'examen — et le sujet change de dimension.
