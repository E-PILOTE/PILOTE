# Catalogue réel — Catégorie ▸ Module ▸ Route ▸ Code

> **GÉNÉRÉ le 2026-09-08** depuis la base LIVE (`module_categories` → `modules`),
> joint à `features/navigation/module_routes.dart` (source unique slug↔route)
> et à `core/router/app_router.dart`.
>
> **C'est la taxonomie de référence de toute l'analyse.** L'organisation en
> dossiers `features/` du code ne la recoupe PAS : un même dossier sert
> plusieurs modules, et un module peut s'étaler sur plusieurs dossiers.
> **Le suivi se fait par MODULE, jamais par dossier.**

**9 catégories · 35 modules** — 32 actifs + 3 Communication (`is_active = false`
au catalogue car **natifs** : livrés à tous les plans, Gratuit compris, donc
hors levier d'abonnement).

## 1. SCOLARITÉ — `scolarite`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Élèves** | `eleves` | `/user/eleves` | `ElevesScreen` | `features/students/screens/eleves_screen.dart` |
| **Inscriptions** | `inscriptions` | `/user/inscriptions` | `InscriptionsScreen` | `features/students/screens/inscriptions_screen.dart` |
| **Orientation** | `orientation` | `/user/orientation` | `OrientationScreen` | `features/vie_scolaire/screens/orientation_screen.dart` |
| **Transferts** | `transferts` | `/user/transferts` | `TransfertsScreen` | `features/students/screens/transferts_screen.dart` |
| **Documents** | `documents` | `/user/documents` | `DocumentsScreen` | `features/students/screens/documents_screen.dart` |
| **Annuaire** | `annuaire` | `/user/annuaire` | `AnnuaireScreen` | `features/students/screens/annuaire_screen.dart` |
| **Cartes scolaires** | `cartes` | `/user/cartes` | `CartesScreen` | `features/cartes/screens/cartes_screen.dart` |

## 2. ENSEIGNEMENT — `enseignement`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Classes** | `classes` | `/user/classes` | `ClassesScreen` | `features/classes/screens/classes_screen.dart` |
| **Niveaux** | `niveaux` | `/user/structure` | `AcademicStructureScreen` | `features/structure/screens/academic_structure_screen.dart` |
| **Matières** | `matieres` | `/user/matieres` | `SubjectsScreen` | `features/structure/screens/subjects_screen.dart` |
| **Programmes** | `programmes` | `/user/programmes` | `ProgrammesScreen` | `features/structure/screens/programmes_screen.dart` |
| **Emploi du Temps** | `emploi-du-temps` | `/user/emploi-du-temps` | `EmploiDuTempsScreen` | `features/structure/screens/emploi_du_temps_screen.dart` |
| **Cahier de Textes** | `cahier-textes` | `/user/cahier-textes` | `CahierTextesScreen` | `features/structure/screens/cahier_textes_screen.dart` |

## 3. ÉVALUATION — `evaluation`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Évaluations & Notes** | `notes` | `/user/notes` | `NotesScreen` | `features/evaluation/screens/notes_screen.dart` |
| **Bulletins** | `bulletins` | `/user/bulletins` | `BulletinsScreen` | `features/evaluation/screens/bulletins_screen.dart` |
| **Conseils de Classe** | `conseils` | `/user/conseils` | `ConseilsScreen` | `features/evaluation/screens/conseils_screen.dart` |
| **Passage en classe supérieure** | `passage` | `/user/passage` | `PassageScreen` | `features/evaluation/screens/passage_screen.dart` |

## 4. EXAMENS & CERTIFICATION — `examens`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Examens** | `examens` | `/user/examens` | `ExamensScreen` | `features/examens/screens/examens_screen.dart` |

## 5. FORMATION PROFESSIONNELLE — `formation-pro`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Stages** | `stages` | `/user/stages` | `StagesScreen` | `features/stages/screens/stages_screen.dart` |

## 6. VIE SCOLAIRE — `vie-scolaire`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Présences Élèves** | `presences-eleves` | `/user/presences` | `PresencesScreen` | `features/vie_scolaire/screens/presences_screen.dart` |
| **Discipline** | `discipline` | `/user/discipline` | `DisciplineScreen` | `features/vie_scolaire/screens/discipline_screen.dart` |
| **Infirmerie** | `infirmerie` | `/user/infirmerie` | `InfirmerieScreen` | `features/vie_scolaire/screens/infirmerie_screen.dart` |
| **Cantine** | `cantine` | `/user/cantine` | `CantineScreen` | `features/vie_scolaire/screens/cantine_screen.dart` |
| **Bibliothèque** | `bibliotheque` | `/user/bibliotheque` | `BibliothequeScreen` | `features/vie_scolaire/screens/bibliotheque_screen.dart` |

## 7. FINANCE — `finance`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Frais de Scolarité** | `frais-scolarite` | `/user/frais` | `FraisScreen` | `features/finance/screens/frais_screen.dart` |
| **Paiements Élèves** | `paiements-eleves` | `/user/paiements` | `PaiementsScreen` | `features/finance/screens/paiements_screen.dart` |
| **Dépenses** | `depenses` | `/user/depenses` | `DepensesScreen` | `features/finance/screens/depenses_screen.dart` |
| **Budget** | `budget` | `/user/budget` | `BudgetScreen` | `features/finance/screens/budget_screen.dart` |

## 8. RESSOURCES HUMAINES — `rh`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Personnel** | `personnel` | `/user/personnel` | `PersonnelScreen` | `features/staff/screens/personnel_screen.dart` |
| **Présences Personnel** | `presences-personnel` | `/user/presences-personnel` | `PresencesPersonnelScreen` | `features/staff/screens/presences_personnel_screen.dart` |
| **Congés** | `conges` | `/user/conges` | `CongesScreen` | `features/staff/screens/conges_screen.dart` |
| **Paie** | `paie` | `/user/paie` | `PaieScreen` | `features/staff/screens/paie_screen.dart` |

## 9. COMMUNICATION (natifs, hors catalogue vendable) — `communication`

| Module | Slug | Route | Écran | Fichier |
|---|---|---|---|---|
| **Annonces** | `annonces` | `/user/annonces` · `/admin/annonces` · `/super/messagerie/annonces` | `StaffAnnouncementsScreen` | `features/communication/` |
| **Messagerie** | `messagerie` | `/user/messagerie` · `/admin/messagerie` · `/super/messagerie` | *(scope-aware)* | `features/communication/` |
| **Événements** | `evenements` | `/user/evenements` · `/admin/evenements` | *(scope-aware)* | `features/communication/` |
| **Notifications** ⚠️ | *(aucun slug)* | `/user/notifications` · `/admin/notifications` · `/super/notifications` | *(scope-aware)* | `features/communication/` |

⚠️ **Notifications existe en tant que pages mais n'a AUCUNE ligne dans la table
`modules`** — contrairement aux trois autres natifs. À qualifier : oubli de
catalogue, ou choix assumé.

---

**35 modules cartographiés.** Tous les modules actifs ont une route
**dédiée** : aucun ne tombe sur le placeholder générique `/user/m/:slug`.

## Hors catalogue — les espaces d'administration

Le catalogue ci-dessus décrit **l'espace école** (`/user/*`, personnel scolaire,
offline-first). Trois espaces n'en font pas partie et s'analysent à part :

| Espace | Rôle | Routes | Code |
|---|---|---|---|
| **Fondateur** | `super_admin` | `/super/*` (19 pages) | `features/super_admin/` |
| **Réseau** | `admin_groupe` | `/admin/*` (12 écrans) | `features/admin_groupe/` |
| **Tutelle** | ministère | dans `/admin/*` | `features/tutelle/` |

⚠️ **Corrigé le 2026-09-09.** Cette ligne rangeait `features/cartes/` sous
Tutelle. C'est **faux** : ce dossier est le module de catalogue `cartes` =
**cartes scolaires des élèves** (catégorie SCOLARITÉ, `/user/cartes`). La
collision est purement lexicale. La cartographie vit dans
`super_admin/screens/national_map_screen.dart` (carte nationale) et
`admin_groupe/screens/regional/` (vue régionale).

## Hors catalogue — le socle transverse

| Brique | Code |
|---|---|
| Authentification, poste partagé, reprise de session | `features/auth/` |
| Mon profil (scope-aware, 3 routes → 1 écran) | `features/profil/` |
| Journal d'audit (scope-aware) | `features/audit/` |
| Navigation, permissions, cascade des 4 verrous | `features/navigation/` |
| Licence & abonnement | `licensing/` |
| Mise à jour du parc | `features/updates/` |
| Tableau de bord & Rapports d'établissement | `features/user/` |
