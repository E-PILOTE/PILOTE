# Balayage mécanique — VIE SCOLAIRE · FINANCE · RH

> Généré le 2026-09-09. Base factuelle des rapports 05, 06 et 07.

## 1. Verrou 4 — périmètre (`classScopeClause`)

| Fichier | Interroge classes/inscriptions | `classScopeClause` | slug(s) passé(s) | `permissionsLoaded` |
|---|---|---|---|---|
| `features/finance/providers/decompte_du_provider.dart` | oui | **NON** | — | **non** |
| `features/finance/providers/frais_provider.dart` | oui | **NON** | — | **non** |
| `features/finance/providers/paiements_provider.dart` | oui | **NON** | — | **non** |
| `features/staff/providers/staff_directory_provider.dart` | oui | **NON** | — | **non** |
| `features/staff/providers/staff_dossier_provider.dart` | oui | **NON** | — | **non** |
| `features/vie_scolaire/providers/biblio_provider.dart` | oui | oui | — | **non** |
| `features/vie_scolaire/providers/cantine_provider.dart` | oui | **NON** | — | **non** |
| `features/vie_scolaire/providers/discipline_provider.dart` | oui | oui | — | **non** |
| `features/vie_scolaire/providers/infirmerie_provider.dart` | oui | oui | — | **non** |
| `features/vie_scolaire/providers/orientation_provider.dart` | oui | **NON** | — | **non** |
| `features/vie_scolaire/providers/presences_provider.dart` | oui | **NON** | — | **non** |
| `features/vie_scolaire/providers/vs_students_provider.dart` | oui | oui | — | **non** |

## 2. `students.is_active` — filtre présent ?

Un élève retiré du registre ne doit plus compter, ni devoir.

| Fichier | Joint `students` | filtre `is_active` |
|---|---|---|
| `features/finance/providers/decompte_du_provider.dart` | oui | **NON** |
| `features/finance/providers/paiements_provider.dart` | oui | oui |
| `features/vie_scolaire/providers/biblio_provider.dart` | oui | oui |
| `features/vie_scolaire/providers/cantine_provider.dart` | oui | **NON** |
| `features/vie_scolaire/providers/discipline_provider.dart` | oui | **NON** |
| `features/vie_scolaire/providers/infirmerie_provider.dart` | oui | **NON** |
| `features/vie_scolaire/providers/orientation_provider.dart` | oui | oui |
| `features/vie_scolaire/providers/presences_provider.dart` | oui | **NON** |
| `features/vie_scolaire/providers/vs_students_provider.dart` | oui | oui |

## 3. Profondeur UI — barème §8 du socle

| Écran | L. | Recher. | Tri | Vide | Charg. | Erreur | Compteur | Action | Détail | Sortie | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `budget_screen.dart` | 271 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (7/9) |
| `depenses_screen.dart` | 477 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (8/9) |
| `frais_screen.dart` | 213 | **✗** | **✗** | ✓ | ✓ | ✓ | ✓ | **✗** | **✗** | **✗** | **L1** (4/9) |
| `paiements_screen.dart` | 434 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **L2** (8/9) |
| `conges_screen.dart` | 479 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (8/9) |
| `paie_screen.dart` | 496 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **L3** (9/9) |
| `personnel_screen.dart` | 395 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **✗** | ✓ | **L2** (7/9) |
| `presences_personnel_screen.dart` | 425 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | **✗** | **✗** | **✗** | **L1** (5/9) |
| `bibliotheque_screen.dart` | 371 | ✓ | **✗** | ✓ | **✗** | **✗** | ✓ | ✓ | ✓ | **✗** | **L1** (5/9) |
| `cantine_screen.dart` | 254 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | **✗** | ✓ | **✗** | **L1** (6/9) |
| `discipline_screen.dart` | 481 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (7/9) |
| `infirmerie_screen.dart` | 270 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (7/9) |
| `orientation_screen.dart` | 404 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (8/9) |
| `presences_screen.dart` | 257 | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✗** | **L2** (7/9) |

## 4. `catch (_) {}` — le zéro menteur

**0 occurrences.**


## 5. Sorties documentaires par domaine

**VIE SCOLAIRE** — 0 service(s) PDF · 0 écran(s) avec aperçu · 0 export(s) CSV


**FINANCE** — 0 service(s) PDF · 1 écran(s) avec aperçu · 0 export(s) CSV

- `features/finance/screens/paiements_sheet.dart`

**RH** — 2 service(s) PDF · 3 écran(s) avec aperçu · 1 export(s) CSV

- `features/staff/screens/paie_screen.dart`
- `features/staff/screens/personnel_dossier_sheet.dart`
- `features/staff/screens/personnel_screen.dart`
- `features/staff/services/payroll_pdf_service.dart`
- `features/staff/services/personnel_export_service.dart`
- `features/staff/services/personnel_export_service.dart`

## 6. Écritures gardées ?

| Fichier | `db.execute` | `runModuleWrite` | `PermissionGate`/`canProvider` |
|---|---|---|---|
| `features/finance/providers/budget_provider.dart` | 3 | — | — |
| `features/finance/providers/depenses_provider.dart` | 3 | — | — |
| `features/finance/providers/paiements_provider.dart` | 4 | — | — |
| `features/staff/providers/leave_provider.dart` | 5 | — | — |
| `features/staff/providers/payroll_provider.dart` | 6 | — | — |
| `features/staff/providers/staff_attendance_provider.dart` | 3 | — | — |
| `features/staff/providers/staff_dossier_provider.dart` | 6 | — | — |
| `features/staff/providers/staff_photo_provider.dart` | 1 | — | — |
| `features/vie_scolaire/providers/biblio_provider.dart` | 5 | — | — |
| `features/vie_scolaire/providers/cantine_provider.dart` | 2 | — | — |
| `features/vie_scolaire/providers/discipline_provider.dart` | 4 | — | — |
| `features/vie_scolaire/providers/infirmerie_provider.dart` | 4 | — | — |
| `features/vie_scolaire/providers/orientation_provider.dart` | 3 | — | — |
| `features/vie_scolaire/providers/presences_provider.dart` | 4 | — | — |

| Écran | `db.execute` via provider | `runModuleWrite` | `PermissionGate`/`canProvider` | `ModuleScaffold` |
|---|---|---|---|---|
| `budget_form.dart` | — | oui | **non** | — |
| `budget_screen.dart` | — | oui | oui | oui |
| `depenses_form.dart` | — | oui | **non** | — |
| `depenses_screen.dart` | — | oui | oui | oui |
| `frais_screen.dart` | — | **non** | **non** | oui |
| `paiements_form.dart` | — | oui | **non** | — |
| `paiements_remboursement.dart` | — | **non** | **non** | — |
| `paiements_screen.dart` | — | **non** | oui | oui |
| `paiements_sheet.dart` | — | oui | **non** | — |
| `agent_creation_dialog.dart` | — | **non** | **non** | — |
| `agent_creation_parts.dart` | — | **non** | **non** | — |
| `agent_fiche_dialog.dart` | — | **non** | **non** | — |
| `conges_form.dart` | — | oui | **non** | — |
| `conges_screen.dart` | — | oui | oui | oui |
| `paie_form.dart` | — | oui | **non** | — |
| `paie_screen.dart` | — | oui | oui | oui |
| `personnel_cycle_kpis.dart` | — | **non** | **non** | — |
| `personnel_dossier_forms.dart` | — | oui | **non** | — |
| `personnel_dossier_sheet.dart` | — | **non** | oui | — |
| `personnel_screen.dart` | — | **non** | **non** | oui |
| `personnel_views.dart` | — | **non** | **non** | — |
| `presences_personnel_screen.dart` | — | oui | oui | oui |
| `biblio_cards.dart` | — | **non** | **non** | — |
| `biblio_forms.dart` | — | oui | **non** | — |
| `bibliotheque_screen.dart` | — | oui | oui | oui |
| `cantine_roll.dart` | — | oui | **non** | — |
| `cantine_screen.dart` | — | **non** | oui | oui |
| `discipline_form.dart` | — | oui | **non** | — |
| `discipline_screen.dart` | — | oui | oui | oui |
| `infirmerie_cards.dart` | — | **non** | **non** | — |
| `infirmerie_form.dart` | — | oui | **non** | — |
| `infirmerie_screen.dart` | — | oui | oui | oui |
| `orientation_screen.dart` | — | **non** | oui | oui |
| `orientation_sheet.dart` | — | oui | **non** | — |
| `presences_roll.dart` | — | oui | **non** | — |
| `presences_screen.dart` | — | **non** | oui | oui |
