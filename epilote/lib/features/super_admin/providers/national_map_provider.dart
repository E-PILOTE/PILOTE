import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final List<_GroupPin>  groups;
}

class _GroupPin {
  const _GroupPin({required this.name, required this.status, required this.planName});
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
  });

  final List<DeptMapEntry> depts;
  final int                totalGroups;
  final int                totalSchools;
  final int                totalStudents;
  final int                coveredDepts;
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
    client.from('students').select('id, school_id'),
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

  // Groupes par département
  final Map<String, List<Map>> groupsByDept = {};
  for (final g in groups) {
    final m = g as Map;
    final dept = m['department'] as String? ?? 'Non précisé';
    groupsByDept.putIfAbsent(dept, () => []).add(m);
  }

  // Construction des entrées par département
  final depts = groupsByDept.entries.map((e) {
    final dept    = e.key;
    final dGroups = e.value;

    return DeptMapEntry(
      dept:         dept,
      coords:       _resolveCoords(dept),
      groupCount:   dGroups.length,
      schoolCount:  schoolsByDept[dept] ?? 0,
      studentCount: studentsByDept[dept] ?? 0,
      activeGroups: dGroups.where((g) => g['subscription_status'] == 'active').length,
      groups:       dGroups.map((g) {
        final plan = g['subscription_plans'] as Map? ?? {};
        return _GroupPin(
          name:     g['name'] as String? ?? '—',
          status:   g['subscription_status'] as String? ?? 'unknown',
          planName: plan['name'] as String? ?? '—',
        );
      }).toList(),
    );
  }).toList()
    ..sort((a, b) => b.groupCount.compareTo(a.groupCount));

  return NationalMapData(
    depts:         depts,
    totalGroups:   groups.length,
    totalSchools:  schools.length,
    totalStudents: students.length,
    coveredDepts:  depts.length,
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
