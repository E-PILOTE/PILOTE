import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'admin_regional_provider.dart';
import 'admin_schools_provider.dart';
import 'education_provider.dart';

// ─── Ligne du tableau analytique (Vue régionale → mode Tableau) ──────────────
// Compose la fiche école (SchoolDetail) avec le GPS (carte régionale), les
// cycles déclarés et un score de complétude — sans dupliquer le registre
// « Mes Écoles » : ici on lit/agrège, on ne gère pas.
class RegionalTableRow {
  const RegionalTableRow({
    required this.school,
    required this.hasGps,
    required this.cycleCodes,
    required this.completeness,
  });

  final SchoolDetail school;
  final bool hasGps;
  final List<String> cycleCodes;
  final int completeness; // 0..100

  int get studentsPerStaff =>
      school.staff > 0 ? (school.students / school.staff).round() : 0;

  bool get hasDirector => school.directorId != null;

  /// Saturation pédagogique = élèves par classe (donnée réelle, sans capacité
  /// déclarée). 0 si pas de classe connue. Sert de proxy d'occupation.
  int get studentsPerClass =>
      school.classes > 0 ? (school.students / school.classes).round() : 0;

  /// Niveau de charge : 0 inconnu, 1 ok (<40), 2 chargé (40-49), 3 surchargé (≥50).
  int get loadLevel {
    final spc = studentsPerClass;
    if (school.classes == 0 || spc == 0) return 0;
    if (spc >= 50) return 3;
    if (spc >= 40) return 2;
    return 1;
  }

  /// Taux d'occupation en % (effectif / capacité déclarée). null si non renseigné.
  int? get occupancyPct {
    final o = school.occupancy;
    return o == null ? null : (o * 100).round();
  }

  /// Niveau d'occupation : 0 inconnu, 1 sous-occupé (<70%), 2 optimal (70-99%),
  /// 3 saturé (≥100%).
  int get occupancyLevel {
    final p = occupancyPct;
    if (p == null) return 0;
    if (p >= 100) return 3;
    if (p >= 70) return 2;
    return 1;
  }
}

// 11 critères issus de la création de l'école → fiabilité de la donnée.
int _completenessOf(SchoolDetail s, bool hasGps, bool hasCycles) {
  bool ok(String? v) => v != null && v.trim().isNotEmpty;
  final flags = <bool>[
    ok(s.code),
    ok(s.address),
    ok(s.city),
    ok(s.department),
    ok(s.phone),
    ok(s.email),
    s.foundedYear != null,
    s.directorId != null,
    ok(s.logoUrl),
    hasGps,
    hasCycles,
  ];
  final filled = flags.where((b) => b).length;
  return (filled * 100 / flags.length).round();
}

// ─── Cycles par école (1 requête groupée, mappés via le catalogue) ───────────
final _schoolCyclesProvider =
    FutureProvider.autoDispose<Map<String, List<String>>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final data   = await ref.watch(adminSchoolsProvider.future);
  final ids    = data.schools.map((s) => s.id).toList();
  if (ids.isEmpty) return {};

  final catalog = await ref.watch(educationCatalogProvider.future);
  final map = <String, List<String>>{};
  try {
    final rows = await client
        .from('school_cycles')
        .select('school_id, cycle_id')
        .inFilter('school_id', ids) as List;
    for (final r in rows) {
      final sid  = r['school_id'] as String?;
      final cid  = r['cycle_id'] as String?;
      if (sid == null || cid == null) continue;
      final code = catalog.cycleById(cid)?.code;
      if (code == null || code.isEmpty) continue;
      map.putIfAbsent(sid, () => []).add(code);
    }
  } catch (_) {}
  return map;
});

// ─── Lignes assemblées (école + GPS + cycles + complétude) ───────────────────
final regionalTableRowsProvider =
    Provider.autoDispose<AsyncValue<List<RegionalTableRow>>>((ref) {
  final schoolsAsync = ref.watch(adminSchoolsProvider);
  final regional     = ref.watch(adminRegionalProvider).valueOrNull;
  final cycles       = ref.watch(_schoolCyclesProvider).valueOrNull ?? const {};

  return schoolsAsync.whenData((d) {
    final gpsIds = {for (final g in (regional?.gpsSchools ?? const [])) g.id};
    return [
      for (final s in d.schools)
        RegionalTableRow(
          school: s,
          hasGps: gpsIds.contains(s.id),
          cycleCodes: cycles[s.id] ?? const [],
          completeness: _completenessOf(
              s, gpsIds.contains(s.id), (cycles[s.id] ?? const []).isNotEmpty),
        ),
    ];
  });
});

// ─── Tri / recherche / filtres du tableau ────────────────────────────────────
enum RegionalSortKey { name, dept, students, staff, ratio, load, occupancy, completeness }

/// Manques actionnables ciblés par le bandeau d'alertes (Tier 2).
enum RegionalGap { noGps, noDirector, noCycle, incomplete }

class RegionalTableQuery {
  const RegionalTableQuery({
    this.search = '',
    this.sortKey = RegionalSortKey.students,
    this.ascending = false,
    this.type, // null = tous, sinon 'public' | 'prive'
    this.activeOnly = false,
    this.incompleteOnly = false,
    this.gap, // null = aucun ; sinon filtre sur un manque précis
  });

  final String search;
  final RegionalSortKey sortKey;
  final bool ascending;
  final String? type;
  final bool activeOnly;
  final bool incompleteOnly;
  final RegionalGap? gap;

  RegionalTableQuery copyWith({
    String? search,
    RegionalSortKey? sortKey,
    bool? ascending,
    Object? type = _unset,
    bool? activeOnly,
    bool? incompleteOnly,
    Object? gap = _unset,
  }) =>
      RegionalTableQuery(
        search: search ?? this.search,
        sortKey: sortKey ?? this.sortKey,
        ascending: ascending ?? this.ascending,
        type: identical(type, _unset) ? this.type : type as String?,
        activeOnly: activeOnly ?? this.activeOnly,
        incompleteOnly: incompleteOnly ?? this.incompleteOnly,
        gap: identical(gap, _unset) ? this.gap : gap as RegionalGap?,
      );

  static const _unset = Object();
}

final regionalTableQueryProvider = StateProvider.autoDispose<RegionalTableQuery>(
    (ref) => const RegionalTableQuery());

/// Applique recherche + filtres + tri sur les lignes brutes.
List<RegionalTableRow> applyRegionalQuery(
    List<RegionalTableRow> rows, RegionalTableQuery q) {
  final needle = q.search.trim().toLowerCase();
  var out = rows.where((r) {
    final s = r.school;
    if (q.type != null && s.type != q.type) return false;
    if (q.activeOnly && !s.isActive) return false;
    if (q.incompleteOnly && r.completeness >= 100) return false;
    if (q.gap != null) {
      final hit = switch (q.gap!) {
        RegionalGap.noGps => !r.hasGps,
        RegionalGap.noDirector => !r.hasDirector,
        RegionalGap.noCycle => r.cycleCodes.isEmpty,
        RegionalGap.incomplete => r.completeness < 100,
      };
      if (!hit) return false;
    }
    if (needle.isEmpty) return true;
    return s.name.toLowerCase().contains(needle) ||
        (s.code?.toLowerCase().contains(needle) ?? false) ||
        (s.city?.toLowerCase().contains(needle) ?? false) ||
        (s.department?.toLowerCase().contains(needle) ?? false);
  }).toList();

  int cmp(RegionalTableRow a, RegionalTableRow b) {
    final r = switch (q.sortKey) {
      RegionalSortKey.name => a.school.name
          .toLowerCase()
          .compareTo(b.school.name.toLowerCase()),
      RegionalSortKey.dept =>
        (a.school.department ?? '').compareTo(b.school.department ?? ''),
      RegionalSortKey.students =>
        a.school.students.compareTo(b.school.students),
      RegionalSortKey.staff => a.school.staff.compareTo(b.school.staff),
      RegionalSortKey.ratio =>
        a.studentsPerStaff.compareTo(b.studentsPerStaff),
      RegionalSortKey.load =>
        a.studentsPerClass.compareTo(b.studentsPerClass),
      RegionalSortKey.occupancy =>
        (a.occupancyPct ?? -1).compareTo(b.occupancyPct ?? -1),
      RegionalSortKey.completeness =>
        a.completeness.compareTo(b.completeness),
    };
    return q.ascending ? r : -r;
  }

  out.sort(cmp);
  return out;
}
