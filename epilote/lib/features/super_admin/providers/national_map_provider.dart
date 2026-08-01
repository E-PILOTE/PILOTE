import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/paged_fetch.dart';
import 'package:latlong2/latlong.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Coordonnées des départements du Congo ────────────────────────────────────
// Source : capitales départementales approximatives
const Map<String, LatLng> _deptCoords = {
  'Brazzaville':    LatLng(-4.2634, 15.2429),
  'Pointe-Noire':   LatLng(-4.7761, 11.8635),
  'Bouenza':        LatLng(-4.1528, 13.5469),
  'Cuvette':        LatLng(-0.4874, 15.9010),
  'Cuvette-Ouest':  LatLng(-0.8705, 14.8175),
  'Kouilou':        LatLng(-4.4600, 11.8500),
  'Lékoumou':       LatLng(-3.6833, 13.3500),
  'Likouala':       LatLng(1.6167, 18.0667),
  'Niari':          LatLng(-4.2000, 12.6833),
  'Plateaux':       LatLng(-2.5431, 14.7578),
  'Sangha':         LatLng(1.6133, 16.0497),
  'Pool':           LatLng(-4.3517, 14.7644),
};

// Centre du Congo
const congoCenter = LatLng(-0.8, 15.2);

// ─── Modèles ──────────────────────────────────────────────────────────────────

class DeptMapEntry {
  const DeptMapEntry({
    required this.dept,
    required this.coords,
    required this.groupCount,
    required this.schoolCount,
    required this.studentCount,
    required this.activeGroups,
    required this.groups,
  });

  final String           dept;
  final LatLng           coords;
  final int              groupCount;
  final int              schoolCount;
  final int              studentCount;
  final int              activeGroups;
  final List<GroupPin>  groups;
}

class GroupPin {
  const GroupPin({required this.name, required this.status, required this.planName});
  final String name;
  final String status;
  final String planName;
}

class NationalMapData {
  const NationalMapData({
    required this.depts,
    required this.totalGroups,
    required this.totalSchools,
    required this.totalStudents,
    required this.coveredDepts,
    required this.totalDepts,
  });

  final List<DeptMapEntry> depts;
  final int                totalGroups;
  final int                totalSchools;
  final int                totalStudents;
  final int                coveredDepts;

  /// Nombre de départements du pays, LU dans la table `departments`.
  ///
  /// ⚠️ Il était écrit en dur — et pas de la même façon selon l'endroit : la
  /// même page affichait « 0/12 départements couverts » dans un encadré et
  /// « 0 / 15 départements couverts » dans celui d'à côté. Deux chiffres
  /// contradictoires sur le découpage administratif du pays, sur l'écran
  /// national d'une plateforme d'État.
  final int totalDepts;

  /// Part du territoire atteinte, 0…1. Zéro tant que le référentiel des
  /// départements n'est pas chargé — plutôt qu'une division par une constante.
  double get coverage => totalDepts == 0 ? 0 : coveredDepts / totalDepts;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final nationalMapProvider = FutureProvider.autoDispose<NationalMapData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    client.from('school_groups').select(
        'id, name, department, subscription_status, '
        'subscription_plans(name)'),
    client.from('schools').select('id, group_id, department'),
    fetchAllRows(() => client.from('students').select('id, school_id')),
  ]);

  final groups   = results[0] as List;
  final schools  = results[1] as List;
  final students = results[2] as List;

  // school_id → département (pour rattacher chaque élève à son département)
  final Map<String, String> schoolToDept = {};
  for (final s in schools) {
    final m = s as Map;
    schoolToDept[m['id'] as String] = m['department'] as String? ?? 'Non précisé';
  }

  // Écoles par département
  final Map<String, int> schoolsByDept = {};
  for (final s in schools) {
    final m = s as Map;
    final dept = m['department'] as String? ?? 'Non précisé';
    schoolsByDept[dept] = (schoolsByDept[dept] ?? 0) + 1;
  }

  // Élèves réels par département (via l'école de chaque élève)
  final Map<String, int> studentsByDept = {};
  for (final st in students) {
    final m   = st as Map;
    final sid = m['school_id'] as String?;
    final dept = (sid != null ? schoolToDept[sid] : null) ?? 'Non précisé';
    studentsByDept[dept] = (studentsByDept[dept] ?? 0) + 1;
  }

  // ── Groupes PRÉSENTS dans chaque département ─────────────────────────────
  //
  // ⚠️ La présence se lit sur les ÉCOLES, pas sur le siège du groupe. Le
  // MEPSA siège à Brazzaville et scolarise à Ouésso, Impfondo et Mossaka : en
  // rattachant les groupes à leur seule adresse administrative, la carte
  // nationale annonçait 3 départements couverts sur 15, alors que les
  // établissements en atteignent la totalité. Sur une vue destinée à un
  // ministère, c'est l'inverse du message : le déploiement paraissait cantonné
  // à trois villes.
  //
  // Un groupe sans aucune école reste rattaché à son siège — sinon il
  // disparaîtrait de la carte au lieu d'y apparaître comme non déployé.
  final Map<String, Map> groupById = {
    for (final g in groups) (g as Map)['id'] as String: g,
  };
  final Map<String, Map<String, Map>> groupsByDept = {};
  for (final s in schools) {
    final m    = s as Map;
    final dept = m['department'] as String? ?? 'Non précisé';
    final gid  = m['group_id'] as String?;
    final g    = gid != null ? groupById[gid] : null;
    if (g != null) {
      groupsByDept.putIfAbsent(dept, () => {})[gid!] = g;
    }
  }
  for (final g in groups) {
    final m   = g as Map;
    final gid = m['id'] as String;
    final has = groupsByDept.values.any((set) => set.containsKey(gid));
    if (!has) {
      final dept = m['department'] as String? ?? 'Non précisé';
      groupsByDept.putIfAbsent(dept, () => {})[gid] = m;
    }
  }

  // Construction des entrées par département
  final depts = groupsByDept.entries.map((e) {
    final dept    = e.key;
    final dGroups = e.value.values.toList();

    return DeptMapEntry(
      dept:         dept,
      coords:       _resolveCoords(dept),
      groupCount:   dGroups.length,
      schoolCount:  schoolsByDept[dept] ?? 0,
      studentCount: studentsByDept[dept] ?? 0,
      activeGroups: dGroups.where((g) => g['subscription_status'] == 'active').length,
      groups:       dGroups.map((g) {
        final plan = g['subscription_plans'] as Map? ?? {};
        return GroupPin(
          name:     g['name'] as String? ?? '—',
          status:   g['subscription_status'] as String? ?? 'unknown',
          planName: plan['name'] as String? ?? '—',
        );
      }).toList(),
    );
  }).toList()
    ..sort((a, b) => b.groupCount.compareTo(a.groupCount));

  var totalDepts = 0;
  try {
    totalDepts = await client.from('departments').count(CountOption.exact);
  } catch (_) {}

  return NationalMapData(
    depts:         depts,
    totalGroups:   groups.length,
    totalSchools:  schools.length,
    totalStudents: students.length,
    coveredDepts:  depts.length,
    totalDepts:    totalDepts,
  );
});

LatLng _resolveCoords(String dept) {
  // Exact match
  if (_deptCoords.containsKey(dept)) return _deptCoords[dept]!;
  // Partial match
  for (final entry in _deptCoords.entries) {
    if (dept.toLowerCase().contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(dept.toLowerCase())) {
      return entry.value;
    }
  }
  // Default: center of Congo
  return congoCenter;
}
