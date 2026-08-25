---
name: finance-categorie
description: Catégorie Finance livrée (Frais/Paiements/Dépenses/Budget) + dépendance Dépenses→Budget ; audit cohérence/scope
metadata: 
  node_type: memory
  type: project
  originSessionId: d4b7d011-2f3d-4ee1-8013-06ea3ffadd28
---

✅ 2026-06-29 (commit `ba0f3f7`) — catégorie **Finance** complète, offline-first, sur 5 tables déjà synchro (`sync_finance`, AUCUN déploiement requis). analyze 0 / build ✓ / fichiers ≤500 lignes. Commitée sur `main`. Plateforme relancée (nouveau bundle) et synchro PowerSync OK.

**4 modules** (`epilote/lib/features/finance/`) :
- **Frais** (`fee_structures`) : barèmes par type (`kFeeTypes`) + **niveau concerné** (`applies_to_level_id`, `schoolLevelOptionsProvider`).
- **Paiements** (`student_payments`) — flagship : recouvrement **Cycle▸Niveau▸Classe** via `ScopeDrilldownPanel` (`paymentsOverviewProvider`→`VsCoverageRow`), atelier classe avec recherche (>8 élèves, scalable 200), fiche élève (`_StudentPaymentsSheet`) + historique + form, lien `fee_structures`, reçu auto `REC-…`, `period_month/year` dérivés de la date.
- **Dépenses** (`expenses`) : grand-livre par poste, graphe catégories, filtres. **`kExpenseCategories` = taxonomie CANONIQUE slug** (personnel/fournitures/equipement/maintenance/services/transport/evenements/investissement/autre).
- **Budget** (`budget_lines`) : prévu (saisi) vs **réalisé DÉRIVÉ des Dépenses**.

**Décision de cohérence clé (dépendance inter-modules Dépenses→Budget)** : le « réalisé » du Budget n'est PLUS saisi à la main — il est calculé live depuis `expensesByCategoryProvider` (Σ dépenses par slug, année active), injecté dans `BudgetLine.actual` par `budgetLinesProvider`. `kBudgetCategories = kExpenseCategories` (slugs partagés), `budgetCategoryLabel = expenseCategoryLabel`. `saveBudgetLine` n'écrit plus `actual` (forcé 0 en base, ignoré). Évite que prévu/réalisé divergent. Voir [[design-gouvernance-anti-redondance]].

**Audit scope (cycle/niveau/classe/trimestre)** demandé par le user — verdict :
- Évaluation : Cycle▸Niveau▸Classe + **Trimestre** (`trimester_id`, sélecteur partagé depuis `academic_year_provider`) ✅ — cf [[evaluation-notes-bulletins]].
- Vie Scolaire : kit `ScopeDrilldownPanel` partagé ✅ — cf [[vie-scolaire-categorie]].
- Paiements : Cycle▸Niveau▸Classe ✅ ; Frais : Niveau ✅.
- Dépenses/Budget : **établissement-wide** (pas de classe/trimestre) = CORRECT (finance d'établissement, pas par classe). Trimestre = « si applicable » → non applicable ici.

**Catégories Dépenses/Budget non couvertes par un futur module** : Personnel (salaires) et Investissement (capex) passent volontairement par les Dépenses pour alimenter le Budget tant que RH/Paie n'existe pas.

Reste roadmap : **RH** (paie, présences personnel, congés) — `staff_members.profile_id` dormant à brancher (cf [[staff-personnel-annuaire]] / [[profil-source-de-verite-droits]]).
