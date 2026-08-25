---
name: powersync-status
description: "PowerSync Cloud configuré ✅ — schéma + sync-rules complets, providers offline-first créés"
metadata: 
  node_type: memory
  type: project
  originSessionId: cf900063-f65b-41b2-9d16-fdd9bffe6e3c
---

## PowerSync Cloud ✅ (28 Mai 2026)

| Paramètre | Valeur |
|---|---|
| Instance | `https://6a185941234fa2bf51a66757.powersync.journeyapps.com` |
| DB Connection | `powersync_role@db.wqpdamlnrwgozfvzjjpo.supabase.co:5432/postgres` |
| SSL | verify-full (IPv6 direct) |
| Client Auth | Supabase JWT HS256 configuré |
| Sync Streams | 22 tables, edition 3 |
| Publication PG | `powersync FOR ALL TABLES` ✅ |

## ⚠️ ACTION REQUISE : Déployer sync-rules.yaml sur PowerSync Cloud
Le fichier local `/home/melack/E-PILOTE/powersync/config/sync-rules.yaml` a été mis à jour.
Il faut l'uploader dans le dashboard PowerSync Cloud pour activer les 10 nouvelles tables.

## Tables synchées (22 au total après déploiement)

### Données plateforme (globales, sans group_id)
- `module_categories` — catégories modules
- `modules` — tous modules actifs
- `plan_modules` — modules inclus dans le plan du groupe

### Structure scolaire (Phase 1)
- `profiles`, `school_groups`, `schools`
- `academic_years`, `trimesters`, `sequences`
- `classes`, `class_enrollments`

### Acteurs (Phase 2)
- `students`, `student_tutors`
- `staff_members`, `teacher_subjects`
- `subjects`

### Quotidien / Évaluation
- `grades`, `attendance_records`, `attendance_entries`

### Finance / Communication
- `student_payments`, `announcements`

## Fichiers Flutter (couche data offline-first)

### Schéma SQLite
- `lib/services/powersync/powersync_schema.dart` — **21 tables** ✅

### Modèles (mapping DB réel, bool SQLite compatible)
- `academic_year_model.dart` — AcademicYearModel, TrimesterModel, SequenceModel ✅
- `class_model.dart` — ClassModel (`capacity` ✓), ClassEnrollmentModel ✅
- `school_model.dart` — SchoolModel (`school_code` ✓) ✅
- `school_group_model.dart` — SchoolGroupModel (`plan_id` ✓) ✅
- `module_model.dart` — ModuleCategoryModel, ModuleModel, PlanModuleModel ✅

### Providers offline-first (db.watch() uniquement)
- `features/structure/providers/academic_year_provider.dart`
  → currentAcademicYearProvider, academicYearsProvider, trimestersProvider,
    sequencesProvider, currentSchoolProvider
- `features/classes/providers/class_provider.dart`
  → classesProvider, classByIdProvider, classEnrollmentsProvider,
    classCountProvider, enrolledStudentCountProvider
  → Mutations: createClass(), archiveClass(), enrollStudent(), withdrawStudent()
- `features/navigation/providers/module_navigation_provider.dart`
  → currentSchoolGroupProvider, activeModulesProvider,
    modulesGroupedByCategoryProvider, hasModuleAccessProvider

## Pattern offline-first (personnel scolaire uniquement)
```dart
// LECTURE
StreamProvider.autoDispose((ref) =>
  db.watch('SELECT * FROM students WHERE school_id = ?', parameters: [id]));

// ÉCRITURE
await db.execute('INSERT OR REPLACE INTO students (id, ...) VALUES (?, ...)', [...]);
```

## Logique navigation dynamique offline
```
profiles.group_id → school_groups.plan_id
plan_modules.plan_id → plan_modules.module_id → modules
modules.category_id → module_categories
```
Provider: `modulesGroupedByCategoryProvider` (JOIN SQLite local, 100% offline)

## Prochaine étape : Phase 2 Acteurs
Tables Supabase à vérifier : `students`, `student_tutors`, `staff_members`, `teacher_subjects`
Ajouter providers offline-first pour chaque table.
