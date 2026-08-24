import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/module_model.dart';
import '../../../data/models/school_group_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

// ─── Groupe scolaire courant (offline-first) ─────────────────────────────────

/// Groupe scolaire de l'utilisateur connecté — lu depuis SQLite PowerSync.
/// Contient plan_id → base de la navigation dynamique offline.
final currentSchoolGroupProvider =
    StreamProvider.autoDispose<SchoolGroupModel?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.groupId == null || profile!.groupId!.isEmpty) {
    return Stream.value(null);
  }
  return db
      .watch(
        'SELECT * FROM school_groups WHERE id = ? LIMIT 1',
        parameters: [profile.groupId],
      )
      .map((rows) =>
          rows.isEmpty ? null : SchoolGroupModel.fromMap(rows.first));
});

// ─── Indicateur de synchro conscient des données locales (offline-first) ─────

/// État de synchro pour l'UI, enrichi de la présence de données locales.
/// Logique offline-first : si la couche locale contient déjà les données du
/// groupe (synchro précédente réussie), on affiche « à jour » même si la
/// connexion stream live n'est pas active à l'instant T (réseau terrain
/// instable). N'alarme avec « Hors ligne » que s'il n'y a vraiment rien.
final syncIndicatorProvider = Provider<SyncUiState>((ref) {
  final base = ref.watch(syncUiStateProvider);
  if (base != SyncUiState.offline) return base; // synced / syncing
  final hasLocalData = ref.watch(currentSchoolGroupProvider).valueOrNull != null;
  return hasLocalData ? SyncUiState.synced : SyncUiState.offline;
});

// ─── Modules du plan courant (offline-first) ─────────────────────────────────

/// Modules actifs auxquels le groupe a accès, enrichis de leur catégorie.
/// Requête 100% locale (SQLite) — fonctionne hors-ligne.
///
/// Logique :
///   profiles.group_id → school_groups.plan_id
///   plan_modules.plan_id → plan_modules.module_id → modules
///   modules.category_id → module_categories
final activeModulesProvider =
    StreamProvider.autoDispose<List<ModuleModel>>((ref) {
  final groupAsync = ref.watch(currentSchoolGroupProvider);
  final planId     = groupAsync.valueOrNull?.planId;

  if (planId == null || planId.isEmpty) {
    return Stream.value([]);
  }

  return db
      .watch(
        '''
        SELECT  m.*,
                mc.name AS category_name,
                mc.icon AS category_icon
        FROM    modules m
        JOIN    module_categories mc ON mc.id = m.category_id
        JOIN    plan_modules pm      ON pm.module_id = m.id
        WHERE   pm.plan_id = ?
        AND     COALESCE(m.is_active, 1) <> 0
        ORDER BY mc.display_order, m.display_order
        ''',
        parameters: [planId],
      )
      .map((rows) => rows.map(ModuleModel.fromMap).toList());
});

// ─── Catégories avec leurs modules ───────────────────────────────────────────

/// Résultat regroupé : catégorie → liste de modules actifs du plan.
/// Utilisé pour construire la sidebar dynamiquement offline.
final modulesGroupedByCategoryProvider =
    StreamProvider.autoDispose<Map<ModuleCategoryModel, List<ModuleModel>>>(
        (ref) {
  final groupAsync = ref.watch(currentSchoolGroupProvider);
  final planId     = groupAsync.valueOrNull?.planId;

  if (planId == null || planId.isEmpty) {
    return Stream.value({});
  }

  return db
      .watch(
        '''
        SELECT  mc.id           AS cat_id,
                mc.name         AS cat_name,
                mc.slug         AS cat_slug,
                mc.icon         AS cat_icon,
                mc.display_order AS cat_order,
                mc.created_at   AS cat_created_at,
                mc.updated_at   AS cat_updated_at,
                m.id            AS mod_id,
                m.name          AS mod_name,
                m.slug          AS mod_slug,
                m.description   AS mod_description,
                m.icon          AS mod_icon,
                m.display_order AS mod_order,
                m.is_active     AS mod_is_active,
                m.category_id   AS mod_category_id,
                m.created_at    AS mod_created_at,
                m.updated_at    AS mod_updated_at
        FROM    module_categories mc
        JOIN    modules m ON m.category_id = mc.id
        JOIN    plan_modules pm ON pm.module_id = m.id
        WHERE   pm.plan_id = ?
        AND     COALESCE(m.is_active, 1) <> 0
        ORDER BY mc.display_order, m.display_order
        ''',
        parameters: [planId],
      )
      .map((rows) {
        final Map<String, ModuleCategoryModel> catMap = {};
        final Map<String, List<ModuleModel>>   modMap = {};

        for (final row in rows) {
          final catId = row['cat_id'] as String;

          catMap.putIfAbsent(
            catId,
            () => ModuleCategoryModel(
              id:           catId,
              name:         row['cat_name']    as String,
              slug:         row['cat_slug']    as String,
              icon:         row['cat_icon']    as String?,
              displayOrder: row['cat_order']   as int? ?? 0,
              createdAt:    DateTime.parse(row['cat_created_at'] as String),
              updatedAt:    DateTime.parse(row['cat_updated_at'] as String),
            ),
          );

          modMap.putIfAbsent(catId, () => []).add(
            ModuleModel(
              id:           row['mod_id']          as String,
              categoryId:   row['mod_category_id'] as String,
              name:         row['mod_name']        as String,
              slug:         row['mod_slug']        as String,
              description:  row['mod_description'] as String?,
              icon:         row['mod_icon']        as String?,
              displayOrder: row['mod_order']       as int? ?? 0,
              isActive:     row['mod_is_active'] == true ||
                            row['mod_is_active'] == 1,
              createdAt:    DateTime.parse(row['mod_created_at'] as String),
              updatedAt:    DateTime.parse(row['mod_updated_at'] as String),
            ),
          );
        }

        final result = <ModuleCategoryModel, List<ModuleModel>>{};
        for (final entry in catMap.entries) {
          result[entry.value] = modMap[entry.key] ?? [];
        }
        return result;
      });
});

// ─── Vérification d'accès à un module ────────────────────────────────────────

/// Vérifie si le plan courant inclut un module donné (par slug).
/// Utilisé pour le guard de navigation offline.
final hasModuleAccessProvider =
    Provider.autoDispose.family<bool, String>((ref, moduleSlug) {
  final modules = ref.watch(activeModulesProvider).valueOrNull ?? [];
  return modules.any((m) => m.slug == moduleSlug);
});

// ─── Données globales (référence plateforme) ──────────────────────────────────

/// Toutes les catégories de modules (référence plateforme).
final allModuleCategoriesProvider =
    StreamProvider.autoDispose<List<ModuleCategoryModel>>((ref) {
  return db
      .watch(
        'SELECT * FROM module_categories ORDER BY display_order',
      )
      .map((rows) => rows.map(ModuleCategoryModel.fromMap).toList());
});

/// Tous les modules actifs (référence plateforme).
final allModulesProvider =
    StreamProvider.autoDispose<List<ModuleModel>>((ref) {
  return db
      .watch(
        'SELECT * FROM modules WHERE COALESCE(is_active, 1) <> 0 '
        'ORDER BY display_order',
      )
      .map((rows) => rows.map(ModuleModel.fromMap).toList());
});
