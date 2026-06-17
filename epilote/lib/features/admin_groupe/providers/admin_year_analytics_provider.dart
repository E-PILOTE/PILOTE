import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESPACE ADMIN_GROUPE — Analyses d'une année scolaire (online / Supabase direct).
//  Ventilation par département / type d'établissement / école + année sélectionnée.
// ══════════════════════════════════════════════════════════════════════════════

// ─── Année sélectionnée pour les analyses (par défaut : courante) ──────────────
final selectedAdminYearIdProvider = StateProvider.autoDispose<String?>((ref) => null);

// ─── Analytics d'une année : par département / par type / par école ────────────
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

  int get departementsCouverts =>
      byDepartment.where((d) => d.ecolesPreparees > 0).length;
  double get tauxAdoption =>
      ecolesTotal == 0 ? 0 : ecolesPreparees / ecolesTotal;
  double get moyenneElevesParClasse =>
      classes == 0 ? 0 : eleves / classes;

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
/// Online (Supabase direct) — agrégation côté client (REST ne fait pas GROUP BY).
final adminYearAnalyticsProvider = FutureProvider.autoDispose
    .family<AdminYearAnalytics, String>((ref, yearId) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminYearAnalytics.empty;

  final schools = await client
      .from('schools')
      .select('id, name, department, school_type')
      .eq('group_id', groupId)
      .eq('is_active', true) as List;
  final classRows = await client
      .from('classes')
      .select('school_id')
      .eq('group_id', groupId)
      .eq('academic_year_id', yearId)
      .eq('is_active', true) as List;
  final enrollRows = await client
      .from('class_enrollments')
      .select('school_id')
      .eq('group_id', groupId)
      .eq('academic_year_id', yearId)
      .eq('status', 'active') as List;

  final classBySchool = <String, int>{};
  for (final r in classRows) {
    final s = r['school_id'] as String?;
    if (s != null) classBySchool[s] = (classBySchool[s] ?? 0) + 1;
  }
  final eleveBySchool = <String, int>{};
  for (final r in enrollRows) {
    final s = r['school_id'] as String?;
    if (s != null) eleveBySchool[s] = (eleveBySchool[s] ?? 0) + 1;
  }

  final bySchool = <YearSchoolStat>[];
  for (final s in schools) {
    final id = s['id'] as String;
    bySchool.add(YearSchoolStat(
      id: id,
      name: (s['name'] as String?) ?? '—',
      department: (s['department'] as String?)?.trim().isNotEmpty == true
          ? s['department'] as String
          : 'Non précisé',
      type: (s['school_type'] as String?) ?? 'autre',
      classes: classBySchool[id] ?? 0,
      eleves: eleveBySchool[id] ?? 0,
    ));
  }
  bySchool.sort((a, b) => b.eleves.compareTo(a.eleves));

  // Agrégation par département
  final deptMap = <String, List<YearSchoolStat>>{};
  for (final s in bySchool) {
    (deptMap[s.department] ??= []).add(s);
  }
  final byDepartment = deptMap.entries.map((e) {
    return YearDeptStat(
      department: e.key,
      ecoles: e.value.length,
      ecolesPreparees: e.value.where((s) => s.adopted).length,
      classes: e.value.fold(0, (a, s) => a + s.classes),
      eleves: e.value.fold(0, (a, s) => a + s.eleves),
    );
  }).toList()
    ..sort((a, b) => b.eleves.compareTo(a.eleves));

  // Agrégation par type d'établissement
  final typeMap = <String, List<YearSchoolStat>>{};
  for (final s in bySchool) {
    (typeMap[s.type] ??= []).add(s);
  }
  final byType = typeMap.entries.map((e) {
    return YearTypeStat(
      type: e.key,
      ecoles: e.value.length,
      classes: e.value.fold(0, (a, s) => a + s.classes),
      eleves: e.value.fold(0, (a, s) => a + s.eleves),
    );
  }).toList()
    ..sort((a, b) => b.eleves.compareTo(a.eleves));

  // Totaux dérivés du réseau ACTIF (bySchool ne porte que sur les écoles
  // actives) → cohérents avec les ventilations et avec adminAcademicYearsProvider.
  // (classRows/enrollRows bruts incluraient des écoles désactivées.)
  return AdminYearAnalytics(
    byDepartment: byDepartment,
    byType: byType,
    bySchool: bySchool,
    ecolesTotal: schools.length,
    ecolesPreparees: bySchool.where((s) => s.adopted).length,
    classes: bySchool.fold(0, (a, s) => a + s.classes),
    eleves: bySchool.fold(0, (a, s) => a + s.eleves),
  );
});
