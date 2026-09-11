# FINANCE — analyse

**Slug catégorie** : `finance` · **Modules** : 4
**Code** : `features/finance/` — 21 fichiers, 5 014 lignes, 9 écrans
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

## A. Vue d'ensemble de la catégorie

Quatre modules qui tiennent l'argent de l'école : ce qui est **dû**
(`frais-scolarite`), ce qui **rentre** (`paiements-eleves`), ce qui **sort**
(`depenses`) et ce qui était **prévu** (`budget`). Le tout hors ligne, sur des
entiers XAF.

**Ce qui va bien** — le chaînage prévu/réalisé est correctement conçu : le
« réalisé » du Budget est **dérivé** du grand-livre des Dépenses par slug de
poste commun, jamais ressaisi (`budget_provider.dart:12-15`). Le numéro de reçu
a été refait pour être unique **sans réseau** (étiquette d'appareil + séquence
locale) après qu'une collision toutes les 16 min 40 s faisait perdre des
encaissements. Aucun `catch (_) {}` dans les 5 014 lignes.

**Ce qui ne va pas** — trois lectures de barème confondaient « pas encore lu »
avec « aucun barème », et le barème vide vaut **zéro dû**. Un caissier pouvait
lire « reste dû : 0 » pendant la fenêtre de chargement. Corrigé (D.5).

---

## B. Fiche par module

### Frais de Scolarité — `frais-scolarite`

| | |
|---|---|
| Route | `/user/frais` · Écran `FraisScreen` (213 l.) |
| Tables | `fee_structures` (lecture seule), `classes`/`school_levels` |
| Périmètre | `own_school` uniquement en base (0 profil `own_classes`) — pas de clause nécessaire |
| Profondeur UI | **L1** (4/9) — **mais voir ci-dessous** |
| Sortie | aucune |

**Ce qu'il fait** — affiche les barèmes applicables, sur deux portées : le
tarif du **réseau** (posé pour toutes les écoles) et celui posé pour cet
établissement.

⚠️ **Ma note de profondeur L1 était une fausse accusation, et je la retire.**
L'écran n'a ni recherche, ni tri, ni action, ni détail — parce qu'il est
**délibérément en lecture seule** depuis le 5 août 2026 : « un montant est un
ACTE DU GROUPE (migration 0096, décision D2). Dans le public il vient d'un
arrêté, dans le privé du siège — l'école est un exécutant »
(`frais_screen.dart:14-19`). Une page pauvre par décision n'est pas une page
pauvre. **Le barème est un fait résolu de la plateforme, pas un défaut d'UI.**

**Ce qui manque réellement** — une **sortie** : l'école ne peut pas imprimer la
grille tarifaire qu'elle applique, alors que c'est le document qu'une famille
demande à l'inscription et qu'un contrôle réclame.

---

### Paiements Élèves — `paiements-eleves`

| | |
|---|---|
| Route | `/user/paiements` · Écran `PaiementsScreen` (434 l.) + `paiements_sheet` (374 l.) + `paiements_form` (282 l.) + `paiements_remboursement` (114 l.) |
| Provider | `paiements_provider.dart` — **707 lignes, le plus gros de la catégorie** |
| Périmètre | ✅ `classesForModuleProvider(kSlugPaiements)` — l. 118 et 369, **fail-closed** sur `classId` venu de la route |
| Profondeur UI | **L2** (8/9) — manque : tri |
| Sortie | ✅ **reçu PDF** (`recu_pdf_service.dart`, `pw.Page` jamais `MultiPage`) |

**Ce qu'il fait** — encaisse, rembourse (`refundPayment`), annule
(`cancelPayment`), génère le numéro de reçu (`genererNumeroRecu`), calcule le
décompte dû, et sort le reçu de la famille.

C'est **le module le plus abouti de l'espace école** après la Paie : périmètre
posé et fail-closed, document officiel produit, remboursement et annulation
traités, année filtrée explicitement.

**Ce qui manque**
- Pas de tri de la liste (par reste dû, par ancienneté de dette) — sur un
  écran de recouvrement, c'est l'action la plus naturelle.
- Pas d'**état de recouvrement imprimable** par classe. Le KPI existe à
  l'écran ; le document que la direction emporte en réunion, non.
  *(Nuance : `/user/rapports` produit un état du recouvrement au niveau
  établissement — c'est une page de DIRECTION, hors périmètre de l'agent. Le
  manque est donc au niveau CLASSE.)*

---

### Dépenses — `depenses`

| | |
|---|---|
| Route | `/user/depenses` · Écran `DepensesScreen` (477 l.) + `depenses_form` (178 l.) |
| Tables | `expenses` (SENSIBLE, gatée `sync_finance`) |
| Profondeur UI | **L2** (8/9) — manque : sortie |
| Sortie | **aucune** |

**Ce qu'il fait** — le grand-livre des sorties, par poste (taxonomie
`kExpenseCategories` partagée avec le Budget).

**Ce qui manque** — **le grand-livre ne s'imprime pas.** C'est la pièce que
tout contrôle de gestion demande en premier, et la contrepartie du reçu côté
recettes. L'écran est par ailleurs complet (recherche, tri, états, actions).

---

### Budget — `budget`

| | |
|---|---|
| Route | `/user/budget` · Écran `BudgetScreen` (271 l.) + `budget_form` (158 l.) |
| Tables | `budget_lines` (SENSIBLE, gatée `sync_finance`) |
| Profondeur UI | **L2** (7/9) — manquent : tri, sortie |
| Sortie | **aucune** |

**Ce qu'il fait** — saisie du **prévu** par poste ; le **réalisé** est dérivé
des Dépenses, jamais saisi. Bonne conception : prévu et réalisé ne peuvent pas
diverger.

**Ce qui manque**
- **Aucun état budgétaire imprimable** (prévu / réalisé / écart par poste) —
  le document de pilotage par excellence.
- ⚠️ **Dette produit connue et assumée** : l'école **vote elle-même** ses
  lignes de budget, alors que le groupe devrait les lui attribuer
  (`saveBudgetLine` vit dans l'espace école). Documentée dans
  `budget-ecole-se-vote-son-budget.md`, marquée **HORS PÉRIMÈTRE**. Situation
  inchangée au 2026-09-09 — je la cite, je ne la re-découvre pas.

---

## C. Relations entre les modules DE cette catégorie

```
  frais-scolarite ──(barème applicable)──► paiements-eleves ──► reçu PDF ✅
        │                                        │
        │                                        └──► décompte dû (decompte_du_provider)
        │
        └── posé par le GROUPE / le ministère (mig. 0096) — l'école exécute

  depenses ──(slug de poste commun)──► budget.réalisé   ← dérivé, jamais saisi ✅
```

La chaîne recette est complète et sort un document. La chaîne dépense est
complète et n'en sort aucun. C'est l'asymétrie de la catégorie.

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|---|
| 1 | `depenses` | Grand-livre imprimable | `grep "showPdfPreviewDialog" features/finance/screens/depenses_*` → 0 | La contrepartie du reçu côté sorties n'existe pas | **M** |
| 2 | `budget` | État budgétaire prévu/réalisé/écart | idem sur `budget_*` | Le document de pilotage manque | **M** |
| 3 | `frais-scolarite` | Grille tarifaire imprimable | idem sur `frais_screen` | La famille et le contrôle demandent ce papier | **S** |
| 4 | `paiements-eleves` | État de recouvrement **par classe** | l'état existe au niveau établissement (`/user/rapports`) | Le professeur principal n'a pas sa liste | **S** |
| 5 | `paiements-eleves` | Tri par reste dû / ancienneté | aucun `sort` dans `paiements_screen.dart` | L'action la plus naturelle d'un écran de recouvrement | **S** |
| 6 | `budget` | Tri des lignes | idem | Confort | **S** |
| 7 | catégorie | Lien avec la **Cantine** | `cantine_provider.dart` n'a aucune référence monétaire | Un frais annexe réel (mig. 0108) jamais facturé — cf. `05-cat-vie-scolaire.md` D.1 #2 | **M** |

### D.2 Doublons et redondances

| # | Modules | Ce qui est dupliqué | Nature | Foyer |
|---|---|---|---|---|
| 1 | `depenses` ↔ `budget` | **Néant** — `kBudgetCategories = kExpenseCategories` et `budgetCategoryLabel = expenseCategoryLabel` : la taxonomie est **explicitement partagée**, une seule source | exemplaire | — |
| 2 | `paiements-eleves` | La lecture du barème apparaît en **3 endroits** (`decompte_du:144`, `paiements:120`, `paiements:362`) | Trois appels au même provider — normal — mais les **trois traitaient l'état de chargement différemment** (cf. D.5) | Une même règle aux trois, désormais appliquée |

### D.3 Données partagées HORS catégorie

| Donnée | Producteur | Consommateurs | Contrat | Risque |
|---|---|---|---|---|
| `fee_structures` | **hors catégorie** — groupe/ministère (mig. 0096, 0101) | `frais-scolarite`, `paiements-eleves`, `inscriptions`, `examens` | Tarif national traduit en niveau d'école par `school_levels.education_level_id` | ⚠️ Sans `AND sl.id IS NOT NULL`, un tarif de 6e tomberait sur les terminales |
| `student_payments` | `paiements-eleves` | `inscriptions` (inscription branchée sur la caisse), `/user/rapports` | Statuts `confirmed`/`refunded` | Un lot perdu = un encaissement disparu |
| `recu_pdf_service` | `paiements-eleves` | **`inscriptions`** (`students/screens/inscriptions_screen.dart:24`) | Le reçu d'inscription est le même objet | Partage voulu, bien fait |
| `expenses` (slug de poste) | `depenses` | `budget` (réalisé dérivé) | Slugs identiques des deux côtés | Un slug divergent viderait le réalisé sans erreur |
| repas servis | `cantine` (VIE SCOLAIRE) | **personne** | — | Recette perdue |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` | `showPdfPreviewDialog` | `Printing.layoutPdf(` | Verdict |
|---|---|---|---|---|---|
| `frais-scolarite` | non | — | — | — | à créer |
| `paiements-eleves` | ✅ reçu | ✅ | ✅ `paiements_sheet.dart` | non | **conforme** |
| `depenses` | non | — | — | — | à créer |
| `budget` | non | — | — | — | à créer |

⚠️ **Correction de mon propre balayage** : la passe automatique annonçait
« 0 service PDF en Finance ». C'est faux — `recu_pdf_service.dart` (155 l.)
existe, est conforme (`pw.Page`, jamais `MultiPage`) et est utilisé par deux
modules. Mon expression de recherche ne l'avait pas reconnu.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Prétend | Réalité |
|---|---|---|---|---|---|
| 1 | `paiements-eleves` | **Zéro menteur sur de l'argent** | `decompte_du_provider.dart:144` | « reste dû : 0 » à côté du bouton « Nouveau paiement » | `.valueOrNull ?? const []` confondait « barème pas encore lu » et « aucun barème ». `baremes.isEmpty` renvoie un `DecompteDu()` **vide** : zéro ligne, zéro dû, zéro versé. Pendant le chargement — et **pour toujours** si la lecture échouait — le caissier lisait un solde nul et laissait repartir la famille. **✅ CORRIGÉ** : erreur remontée, chargement distinct de vide |
| 2 | `paiements-eleves` | Zéro menteur | `paiements_provider.dart:120` | Taux de recouvrement | Le **dû** tombait à zéro pendant que l'**encaissé** affichait de l'argent réel : 100 % de recouvrement affiché sur un écran de recouvrement. **✅ CORRIGÉ** (`await …future`, la forme exigée par la mémoire projet) |
| 3 | `paiements-eleves` | Zéro menteur | `paiements_provider.dart:362` | Reste dû par élève d'une classe | Idem, sur la liste de classe. **✅ CORRIGÉ** |
| 4 | catégorie | — | — | — | **Aucun `catch (_) {}` dans les 5 014 lignes** |

⚠️ Les 3 `valueOrNull ?? const {}` restants (`budget_provider.dart:53,138,139`)
portent sur `expensesByCategoryProvider`, qui alimente le **réalisé** du budget.
Même famille, gravité moindre (un réalisé à zéro se lit comme « rien dépensé »,
ce qui est visible, là où un dû à zéro se lit comme « rien à payer », ce qui ne
l'est pas). **Non corrigés — à traiter dans la même passe que le reste.**

### D.6 Dette de structure

| Fichier | Lignes | Couture proposée |
|---|---|---|
| `providers/paiements_provider.dart` | **707** | Trois responsabilités distinctes : la **vue d'ensemble** (`paymentsOverviewProvider`, l. 112-360), les **lectures par classe/élève** (l. 364-585), et les **écritures** (`refundPayment`, `savePayment`, `cancelPayment`, `genererNumeroRecu`, l. 586-707). Le troisième bloc est un `paiements_actions.dart` naturel. |

Les 20 autres fichiers sont sous la cible de 500 lignes.

### D.7 Désalignements catalogue ↔ code

1. **Aucun désalignement de rangement** : les 4 modules du catalogue
   correspondent aux 4 écrans de `features/finance/`.
2. **`frais-scolarite` est catalogué comme un module opérable, il est en
   lecture seule.** Ce n'est pas un bug — c'est la décision D2 (mig. 0096) —
   mais le catalogue vend un module dont l'école ne peut rien faire d'autre que
   regarder. Les dix verbes de `profile_permissions` (`create`, `update`,
   `delete`, `validate`, `approve`…) n'ont aucun effet sur lui. **À noter au
   catalogue.**
3. **Périmètre : 0 profil `own_classes` sur les 4 modules** (relevé live). Les
   providers Finance n'ont donc pas de `classScopeClause` — et c'est
   **cohérent**, pas un trou. À ne pas « corriger » sans changer d'abord la
   politique de profils.

## E. Les cinq choses à faire en premier

1. **Terminer la passe « je ne sais pas ≠ zéro » sur le budget.** Les trois
   sites critiques sont corrigés ; `budget_provider.dart:53,138,139` restent.
   Sur de l'argent, c'est le défaut qu'il faut éliminer complètement, pas
   presque.
   *Gain : plus aucun montant faux affiché comme un fait · Effort : XS.*

2. **Le grand-livre des Dépenses en PDF.** Le socle existe et la catégorie
   sait déjà s'en servir (le reçu). C'est la pièce manquante la plus demandée
   d'un contrôle de gestion.
   *Gain : la chaîne dépense produit enfin un document · Effort : M · Entrée :
   `features/finance/screens/depenses_screen.dart`.*

3. **L'état budgétaire prévu / réalisé / écart.** Le calcul existe déjà
   (`budgetReelProvider`) ; il ne manque que la sortie.
   *Gain : le document de pilotage · Effort : S · Entrée :
   `features/finance/providers/budget_provider.dart:136`.*

4. **Brancher la Cantine sur la caisse** — voir `05-cat-vie-scolaire.md` E.2.
   Le point d'entrée côté Finance est `services/bareme_applicable.dart` (frais
   annexe cumulable, mig. 0108).
   *Gain : une recette réelle cesse d'être perdue · Effort : M.*

5. **Trier le recouvrement par reste dû**, et découper
   `paiements_provider.dart` (707 l.) en sortant ses écritures.
   *Gain : le geste quotidien du caissier, et un fichier ramené sous la cible ·
   Effort : S.*
