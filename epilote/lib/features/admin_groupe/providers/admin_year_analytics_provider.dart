import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESPACE ADMIN_GROUPE — Analyses d'une année scolaire (online / Supabase).
//
//  La ventilation par école vient de la RPC `academic_year_school_stats` : un
//  GROUP BY côté Postgres, une ligne par établissement. La version précédente
//  rapatriait toutes les lignes de `classes` et `class_enrollments` de l'année
//  pour les compter en Dart — intenable à 1 000 écoles, et surtout exposé à la
//  troncature silencieuse de PostgREST.
//
//  Les regroupements par département et par type restent côté client : ils
//  portent sur la liste des écoles (37 aujourd'hui, 1 000 à la cible), c'est-à-
//  dire une poignée de lignes déjà en mémoire — pas la peine d'un aller-retour
//  de plus.
// ══════════════════════════════════════════════════════════════════════════════

// ─── Année sélectionnée pour les analyses (par défaut : courante) ─────────────
final selectedAdminYearIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class YearDeptStat {
  const YearDeptStat({
    required this.department,
    required this.ecoles,
    required this.ecolesPreparees,
    required this.classes,
    required this.eleves,
  });
  final String department;
  final int ecoles, ecolesPreparees, classes, eleves;
}

class YearTypeStat {
  const YearTypeStat({
    required this.type,
    required this.ecoles,
    required this.classes,
    required this.eleves,
  });
  final String type;
  final int ecoles, classes, eleves;
}

class YearSchoolStat {
  const YearSchoolStat({
    required this.id,
    required this.name,
    required this.department,
    required this.type,
    required this.classes,
    required this.eleves,
  });
  final String id, name, department, type;
  final int classes, eleves;
  bool get adopted => classes > 0;
}

class AdminYearAnalytics {
  const AdminYearAnalytics({
    required this.byDepartment,
    required this.byType,
    required this.bySchool,
    required this.ecolesTotal,
    required this.ecolesPreparees,
    required this.classes,
    required this.eleves,
  });

  final List<YearDeptStat> byDepartment;
  final List<YearTypeStat> byType;
  final List<YearSchoolStat> bySchool;
  final int ecolesTotal, ecolesPreparees, classes, eleves;

  /// Départements où au moins une école a préparé l'année.
  int get departementsCouverts =>
      byDepartment.where((d) => d.ecolesPreparees > 0).length;

  double get tauxAdoption =>
      ecolesTotal == 0 ? 0 : ecolesPreparees / ecolesTotal;

  double get moyenneElevesParClasse => classes == 0 ? 0 : eleves / classes;

  /// Établissements sans aucune classe ouverte — la cible des relances.
  List<YearSchoolStat> get ecolesEnRetard =>
      bySchool.where((s) => !s.adopted).toList();

  static const empty = AdminYearAnalytics(
    byDepartment: [],
    byType: [],
    bySchool: [],
    ecolesTotal: 0,
    ecolesPreparees: 0,
    classes: 0,
    eleves: 0,
  );
}

/// Ventilation d'une année par département / type d'établissement / école.
final adminYearAnalyticsProvider = FutureProvider.autoDispose
    .family<AdminYearAnalytics, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminYearAnalytics.empty;

  final rows = await client
      .rpc('academic_year_school_stats', params: {'p_year_id': yearId}) as List;

  final bySchool = rows
      .map((r) => YearSchoolStat(
            id: r['school_id'] as String,
            name: (r['school_name'] as String?) ?? '—',
            department: (r['department'] as String?) ?? 'Non précisé',
            type: (r['school_type'] as String?) ?? 'autre',
            classes: (r['classes'] as num?)?.toInt() ?? 0,
            eleves: (r['eleves'] as num?)?.toInt() ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.eleves.compareTo(a.eleves));

  // ── Agrégation par département ───────────────────────────────────────────
  final deptMap = <String, List<YearSchoolStat>>{};
  for (final s in bySchool) {
    (deptMap[s.department] ??= []).add(s);
  }
  final byDepartment = deptMap.entries
      .map((e) => YearDeptStat(
            department: e.key,
            ecoles: e.value.length,
            ecolesPreparees: e.value.where((s) => s.adopted).length,
            classes: e.value.fold(0, (a, s) => a + s.classes),
            eleves: e.value.fold(0, (a, s) => a + s.eleves),
          ))
      .toList()
    ..sort((a, b) => b.eleves.compareTo(a.eleves));

  // ── Agrégation par type d'établissement ──────────────────────────────────
  final typeMap = <String, List<YearSchoolStat>>{};
  for (final s in bySchool) {
    (typeMap[s.type] ??= []).add(s);
  }
  final byType = typeMap.entries
      .map((e) => YearTypeStat(
            type: e.key,
            ecoles: e.value.length,
            classes: e.value.fold(0, (a, s) => a + s.classes),
            eleves: e.value.fold(0, (a, s) => a + s.eleves),
          ))
      .toList()
    ..sort((a, b) => b.eleves.compareTo(a.eleves));

  return AdminYearAnalytics(
    byDepartment: byDepartment,
    byType: byType,
    bySchool: bySchool,
    ecolesTotal: bySchool.length,
    ecolesPreparees: bySchool.where((s) => s.adopted).length,
    classes: bySchool.fold(0, (a, s) => a + s.classes),
    eleves: bySchool.fold(0, (a, s) => a + s.eleves),
  );
});
