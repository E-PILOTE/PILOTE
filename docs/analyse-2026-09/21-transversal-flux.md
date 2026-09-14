# PASSE TRANSVERSALE — FLUX DE DONNÉES INTER-MODULES

**Objet** : ce que chaque module **produit** pour les autres, ce qu'il en
**consomme**, et les endroits où la chaîne se rompt sans le dire.
**Date** : 2026-09-09 · conduite après les douze rapports.

> Un module ne se juge pas seul. La plupart des défauts trouvés dans cette
> analyse ne sont pas *dans* un module : ils sont **entre deux**, sur une
> colonne qu'un module écrit et qu'un autre lit avec une autre idée en tête.
>
> Cette passe cartographie les colonnes de contact, et dit pour chacune ce qui
> se passe si l'un des deux côtés change d'avis.

---

## A. La colonne vertébrale : `class_enrollments`

**C'est la table la plus lue de la plateforme.** Tout l'espace école y entre.

```
              ┌──────────────────────────────────────────────────────────┐
              │             class_enrollments  (10 364 lignes)           │
              │  student_id · class_id · academic_year_id · status       │
              │  withdrawal_motif · exemption_rate · promotion_decision  │
              └──────────────────────────────────────────────────────────┘
                   ▲                                        │
    ÉCRIT PAR      │                                        │  LU PAR
    ───────────    │                                        ▼  ──────────
  class_provider ──┤  inscription, sortie,           ┌──► eleves        (la fiche)
                   │  réaffectation                  ├──► classes       (l'effectif)
  passage_provider ┤  promotion_decision             ├──► notes         (qui est noté)
  cloture_examen ──┤  clôture d'année                ├──► bulletins     (qui a un bulletin)
  non_revenus ─────┤  élèves non revenus             ├──► paiements     (qui doit quoi)
  discipline ──────┘  exclusion définitive           ├──► etat-rentree  (l'effectif déclaré)
                                                     ├──► examens       (qui est candidat)
                                                     ├──► cartes        (qui a une carte)
                                                     └──► rapports      (les états signés)
```

*Relevé : `grep -rn "INSERT INTO class_enrollments\|UPDATE class_enrollments" lib/`
→ cinq fichiers, dans quatre domaines différents.*

**Cinq écrivains, neuf lecteurs.** Chaque écrivain doit donc respecter le
contrat de *tous* les lecteurs — et ce contrat n'est écrit nulle part en un
seul endroit.

### Les trois contrats implicites de cette table

| Contrat | Qui doit le tenir | Ce qui arrive s'il est rompu |
|---|---|---|
| `status = 'active'` **et** `students.is_active <> 0` définissent l'effectif | tout lecteur d'effectif | Un élève retiré du registre reste compté : l'école se déclare plus nombreuse qu'elle ne l'est, et **les dotations suivent** |
| `withdrawal_motif` est renseigné à chaque sortie — via `setEnrollmentExit`, jamais par un `UPDATE` en ligne | `transferts`, `eleves`, `discipline` | La sortie disparaît de `v_sorties_par_motif` — la statistique nationale des abandons |
| `exemption_rate` s'applique **ligne à ligne**, pas sur le total | `finance` | Une exonération de scolarité remettrait aussi la cantine |

Les trois ont été trouvés rompus au moins une fois pendant cette analyse, et
tous trois sont corrigés (voir `01-cat-scolarite.md`, `06-cat-finance.md`).

---

## B. La chaîne pédagogique

```
  structure/matieres ──► class_subjects (coefficient EFFECTIF, 4 564 lignes)
        │                        │
        │                        ├──────────────────────┐
        ▼                        ▼                      ▼
   evaluations ──► grades ──► bulletins ──────────►  MOTEUR ÉCOLE (offline)
   (15 672)      (501 012)   (21 456)                 COALESCE(cs, subj) ✅
        │                        │
        │                        ├──────────────────►  MOTEUR RÉSEAU (online)
        │                        │                      lit class_subjects ✅ (2026-09-10)
        │                        │
        │                        └──────────────────►  PALMARÈS — get_passage_merit()
        │                                               ⏳ migration 0205 écrite,
        │                                                  NON appliquée
        ▼
   conseils ──► bulletins.decision        (félicitations · avertissement · blâme)
        │
        ▼
   passage  ──► class_enrollments.promotion_decision   (passe · redouble · reoriente)
```

### ⚠️ Le piège de vocabulaire, à connaître avant d'écrire une ligne

`bulletins.decision` et `class_enrollments.promotion_decision` **ne sont pas la
même chose**, et rien dans leur nom ne le dit :

| Colonne | Ce qu'elle porte | Valeurs |
|---|---|---|
| `bulletins.decision` | la **distinction du conseil de classe** | `felicitations`, `encouragements`, `tableau_honneur`, `avertissement_travail`, `avertissement_conduite`, `blame` |
| `class_enrollments.promotion_decision` | le **verdict annuel de passage** | `passe`, `redouble`, `reoriente` |

Écrire « Admis en classe supérieure » dans `bulletins.decision` ne lève **aucune
erreur** : `awardFor()` rend `null`, le bulletin s'affiche sans distinction, et
les compteurs du module Conseils restent à zéro. Aucun message, aucun log.

### La deuxième rupture : le catalogue de matières

**Trouvée et corrigée pendant cette analyse.** 94 des 95 matières en base
portent `school_id IS NULL` (elles appartiennent au **groupe**, pas à une
école). L'écran des matières n'en montrait qu'**une** — celle qui avait un
`school_id`.

L'effet ne s'arrêtait pas à cet écran : le catalogue vide se propageait dans
`class_subjects`, donc dans les évaluations proposées, donc dans le périmètre
`own_classes` de chaque enseignant. Une seule condition manquante
(`OR (s.school_id IS NULL AND s.group_id = ?)`) vidait la moitié pédagogique de
l'application.

---

## C. La chaîne financière

```
  fee_structures ──┐
  (barème publié)  │      ⚠️ Si AUCUN barème n'est publié :
                   ├──►  duScolarite() → « je ne sais pas », JAMAIS 0
  class_enrollments│      (source unique : finance/providers/obligation_provider.dart:123)
  .exemption_rate ─┘                │
                                    ├──► decompte_du_provider  (le guichet : « il reste 5 000 sur la cantine »)
                                    ├──► paiements_provider    (le tableau : dû · versé · reste)
                                    └──► recu_pdf_service      (le reçu — le solde y est OMIS s'il est inconnu)
                                             │
  student_payments (10 423) ◄────────────────┘
        │
        ├──► rapports du réseau  (état de recouvrement signable)
        └──► tableau de bord groupe (courbe des recettes)
```

**Ce que ce schéma dit de bon** : `duScolarite` est une **source unique**, et
les trois consommateurs la respectent. `decompte_du_provider` l'écrit
lui-même : « Ce fichier ne DÉCIDE de rien. Il décompose ce que `duScolarite`
calcule ».

**Ce qui était rompu et l'est moins** :

- `decompte_du_provider` rendait un `DecompteDu()` **tout à zéro** pendant le
  chargement du barème → le caissier lisait « reste dû : 0 » sur un élève
  impayé. *Corrigé* : l'état de chargement et l'état d'erreur remontent
  désormais jusqu'à l'écran.
- Les deux lectures qui alimentent le **réseau** (rapports, courbe) étaient
  plafonnées à 1 000 lignes sur 3 461 paiements. *Corrigé* — voir
  `24-transversal-echelle.md`.

⚠️ **Un reçu n'imprime jamais « solde : 0 F » quand le solde est inconnu.** Il
l'omet (`recu_pdf_service.dart:51`). C'est la doctrine du zéro menteur portée
jusque sur le papier, et il faut la préserver : un reçu se réimprime des mois
plus tard, quand le solde du jour n'est plus celui du jour de l'encaissement.

---

## D. La chaîne des examens — le seul flux qui sort de l'école

```
   MINISTÈRE (tutelle)
        │  peuple le référentiel national — PAS le super_admin
        │  (faille SECURITY DEFINER fermée : migrations 0070/0071)
        ▼
   national_exams ──► exam_eligibility_rules ──► exam_sessions
        │                                              │
        │                                              ▼
        │                                      exam_candidates (2 470)
        │                                              │  dossier_status · result
        │                                              ▼
        │                                      transmissions ──► transmission_items
        │                                        (dépôt opposable à la DEC)
        ▼
   fee_structures.applies_to_exam_id  ──►  frais d'examen ──► duScolarite
```

**Deux contrats fragiles :**

1. `fee_structures.exam_session_id` **n'a jamais été renseigné une seule fois
   en production** — un ministère fixe ses frais *avant* d'ouvrir la session.
   Le ciblage réel est `applies_to_exam_id`, et le poste résout la session de
   son année scolaire. Sans cette colonne sur le poste, aucun barème n'est
   trouvé et **la caisse de l'examen reste fermée**.
2. `exam_excluded` / `exam_override_id` sur `classes` décident quelles classes
   présentent quel examen. Ce sont des colonnes de `classes`, écrites par la
   structure et lues par les examens : encore un contrat entre deux catégories.

---

## E. La chaîne des droits — ce qui décide de tout le reste

```
  plan_modules ──────────────► entitlement ──► verrou 2 (impayé) + verrou 3a (plan)
       (ce que le groupe a acheté)                    │
                                                      ▼
  profile_permissions ──────► myPermissions ──► verrou 3b (can_read/create/…)
       (10 booléens par module)                       │
                                    data_scope ───────┴──► verrou 4 (own_classes | own_school)
                                                             │
                                                             ▼
                                            classScopeClause(ref, '<slug>')
                                            classesForModuleProvider('<slug>')
```

⚠️ **Chaque écran doit appliquer le périmètre de SON module**, pas celui d'un
autre. Le tableau de bord d'accueil fait exception et le dit
(`dashboard_chart_parts.dart:10` : « le tableau de bord n'est pas un module et
n'a donc pas de `data_scope` propre ; le périmètre du module `classes` est
celui qui a du sens »). Une exception écrite est une décision ; une exception
tacite est un défaut.

⚠️ **`permissionsLoaded(ref)` précède toute clause de périmètre.** Sans lui,
un écran interroge la base pendant que les droits chargent, obtient un
périmètre vide, et affiche « aucun élève » à un enseignant qui en a trente.

**Le défaut trouvé sur cette chaîne** — et il n'était pas dans les verrous,
mais à côté : `/user/journal-audit` n'est pas un module, il échappait donc au
verrou 3, et le verrou 1 (rôle) ne le nommait pas. Voir
`12-socle-transverse.md` §B.

---

## F. Le flux qui ne remonte pas : l'audit

```
  TOUTES les tables ──(déclencheur SQL)──► audit_logs ──► journal d'audit
                                                │
                                                └──► « Mon activité » (profil)
```

`piste_audit_test` garde trois propriétés fortes, et elles méritent d'être
citées parce qu'elles sont rarement tenues : **le déclencheur ne lève jamais**
(le journal ne coûte jamais la donnée qu'il observe), **il se tait quand
personne n'agit**, et **il n'enregistre que les colonnes qui ont bougé**.

⚠️ `audit_logs` est **en ligne dans les trois espaces**, y compris côté école.
C'est assumé — une donnée de gouvernance se consulte en ligne — et l'écran dit
explicitement qu'il lui faut le réseau (`audit_screen.dart:100`).

---

## G. Récapitulatif : les colonnes de contact à surveiller

| Colonne | Producteur | Consommateurs | Ce qui casse si le contrat change |
|---|---|---|---|
| `class_enrollments.status` | inscriptions, passage | 9 modules | L'effectif déclaré, donc les dotations |
| `class_enrollments.withdrawal_motif` | transferts, eleves | `v_sorties_par_motif` | La statistique nationale des abandons |
| `class_enrollments.exemption_rate` | inscriptions | finance | Une exonération qui déborde sur la cantine |
| `class_enrollments.promotion_decision` | passage | palmarès, réinscription | ⚠️ à ne pas confondre avec `bulletins.decision` |
| `classes.cycle_code/level_code/level_order` | structure | états, registre, documents, KPI | Un faux ORDRE sur un document signé (corrigé, cf. `20-…` B.2) |
| `class_subjects.coefficient` | structure | bulletin ✅ · dossier réseau ✅ · ⏳ `get_passage_merit()` en base | Deux moyennes différentes pour un même élève. Gardé par `coefficient_effectif_test` |
| `subjects.school_id IS NULL` | groupe | matières, class_subjects, périmètres | Le catalogue pédagogique vide (corrigé) |
| `fee_structures.applies_to_exam_id` | ministère / groupe | finance, examens | La caisse de l'examen fermée |
| `bulletins.status = 'published'` | évaluation | bulletins, dossier réseau | Un brouillon d'enseignant dans un dossier ministériel |
| `students.is_active` | eleves | 12 lectures d'effectif | Un élève retiré compté partout |
| `plan_modules` → `entitlement` | fondateur | verrous 2 et 3 | 32 modules qui disparaissent d'un coup |
| `schools` par `group_id` | fondateur | **le PRIX** (mig. 0159) | Une facturation fausse |

---

## H. Les trois choses à faire

1. **Écrire le contrat de `class_enrollments` en un seul endroit.** Cinq
   écrivains, neuf lecteurs, trois contrats implicites — et les trois ont été
   trouvés rompus au moins une fois. Un fichier de doctrine à côté de la table,
   ou un test qui énonce les trois, vaut mieux que la mémoire de qui les a
   corrigés.
   *Effort : S.*

2. **Appliquer la migration 0205** (`20-…` §B.1) — la moitié « base » du
   coefficient effectif. Le client est corrigé, la fonction SQL attend son
   exécution. Seul flux capable de produire deux chiffres officiels
   contradictoires sur le même élève.
   *Effort : XS — la migration est écrite.*

3. **Nommer les deux « décisions ».** `bulletins.decision` et
   `class_enrollments.promotion_decision` se confondent à la lecture et ne
   lèvent aucune erreur quand on les intervertit. Un test qui refuse une valeur
   hors de l'énumération attendue, de chaque côté, coûte une heure.
   *Effort : S.*
