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

## 📋 Complétude déclarée — Finance face à `ANALYSE.md` (audit du 2026-08-25)

Le cahier des charges annonce **FINANCE (7)** :
`frais-scolarite` · `paiements-eleves` · `facturation-ecole` · `depenses` ·
`budget` · `comptabilite` · `mobile-money`.

**Quatre existent. Trois n'existent même pas comme LIGNES dans `modules`** —
donc ni attribuables, ni au catalogue, ni signalés « à venir » :

| Manquant | Ce que ce serait | Couvert ailleurs ? |
|---|---|---|
| `facturation-ecole` | émettre un avis d'échéance / une facture AVANT paiement | non — l'école ne sait produire qu'un REÇU, après |
| `comptabilite` | comptabilité en partie double, grand-livre | non — `depenses` tient un livre de postes, pas une comptabilité |
| `mobile-money` | encaissement par API MTN / Airtel | non — Phase 2 assumée par le cahier |

✅ **Règle métier n°8, Phase 1 : satisfaite.** `kPaymentMethods` = espèces,
MTN Money, Airtel Money. L'API (Phase 2) est absente, conformément au découpage.

❌ **Règle métier n°4 — « Données financières : 5 ans » : AUCUNE implémentation.**
Pas de purge, pas d'archivage, pas de politique de rétention nulle part.

### ⚠️ `due_day_of_month` est décoratif

Le groupe le saisit (`admin_fee_form_dialog`), l'école l'affiche
(`frais_screen.dart:189` — « échéance le 5 ») et **aucun calcul ne s'en sert** :
`moisDus` compte des mois ENTAMÉS. Conséquence concrète : le 3 du mois, une
famille apparaît déjà débitrice de ce mois alors que l'école lui a donné
jusqu'au 5. Dans un établissement, cela finit par un enfant renvoyé chez lui.

⚠️ Arbitrer avant d'y toucher : s'en servir CHANGE ce qu'une famille doit un
jour donné. Les deux modèles se défendent (`obligation.dart` assume « aucune
table d'échéances »). Le défaut certain est l'incohérence : un réglage qui
s'édite, s'affiche, et ne fait rien.

### Autres manques nommés

- **Aucun suivi des impayés** au-delà de la pastille de couleur par classe :
  ni liste des débiteurs, ni export, ni relance. Le catalogue promet pourtant
  « suivi des impayés » (`module_coming_soon.dart:46`).
- **Deux soldes par famille** — scolarité dans Finance, examen dans Examens.
  Mesuré à Ouésso : 4 000 F réellement encaissés, écran Paiements « Encaissé :
  0 ». Voir [[chantier-bareme-classe-solde-eleve]].

## 🩸 Depuis le MOINS PRIVILÉGIÉ — 0114 / 0115 / 0116 (2026-08-25)

Tout avait été vérifié avec les droits d'un directeur ou du service. Rejoué en
production avec ceux d'un compte ordinaire (transaction annulée), le tableau
change.

**`payments_tenant` était `FOR ALL` sur « même groupe, même école ».** Un
ENSEIGNANT lisait, MODIFIAIT et SUPPRIMAIT chaque versement de son école par un
simple appel PostgREST. 276 comptes : 202 enseignants, 37 surveillants,
37 secrétaires. `expenses` / `budget_lines`, eux, étaient bien gardés.

⚠️ **Le remède évident était FAUX.** `auth_sync_finance()` se calcule depuis
`depenses, budget, personnel, presences-personnel, conges, paie` —
`paiements-eleves` n'y figure PAS. Gater dessus aurait renvoyé 42501 à un
caissier, code fatal ⇒ lot entier perdu.

⚠️⚠️ **Et ma première correction (0114) était fausse aussi.** TROIS écrans
encaissent, pas un :

| Écran | Module | Qui le détient |
|---|---|---|
| `paiements_form.dart` | `paiements-eleves` | Comptabilité, Direction |
| `inscriptions_frais_card.dart` | `inscriptions` | **Secrétariat** aussi |
| `exam_payment_dialog.dart` | `examens` | **Secrétariat** aussi |

Au Congo **le versement FAIT l'inscription** : la carte encaisse et imprime le
reçu devant la famille. 0116 corrige — créer sur l'UN des trois. Mesuré après :
Direction ✅ · Secrétariat ✅ · Enseignant ✗ · Vie scolaire ✗. 239 des 276
comptes restent fermés.

💡 **La leçon** : un droit d'écriture ne se déduit pas du NOM d'un module, mais
des ÉCRANS qui écrivent. Chercher `savePayment` AVANT d'écrire la policy.

**0115 — un filet qui détruisait plus que la chute.** `authenticated` n'avait
pas EXECUTE sur `generate_receipt_number()`, appelée par le trigger quand le
numéro de reçu manque ⇒ 42501 ⇒ lot entier perdu. Invisible parce que
`savePayment` fournit toujours le numéro. Repli serveur vérifié :
`REC-2026-001078` (format différent du client, `REC-<code école>-…` — assumé).

⚠️ **La LECTURE reste ouverte à l'école, et c'est délibéré** : la carte des
frais lit le décompte, et tous les profils ont `inscriptions`. Idem pour la
sync-rule — `student_payments` RESTE dans `by_school`, décision examinée et
documentée dans `sync-rules.yaml` : sans ces lignes sur le poste, la secrétaire
verrait « rien versé » et réclamerait deux fois. Un défaut de confidentialité se
répare ; une famille qui paie deux fois, non. Le levier est la configuration des
profils d'accès, pas les sync-rules.

💡 Contradiction repérée en lisant le cahier, HORS Finance : `ANALYSE.md` §8.7
donne les mentions à Excellent ≥16 / Très Bien 14 / Bien 12 / Assez Bien 10,
là où `get_mention()` en base pose ≥18 / ≥16 / ≥14 / ≥12 / ≥10. À trancher lors
de l'audit d'Évaluation.
