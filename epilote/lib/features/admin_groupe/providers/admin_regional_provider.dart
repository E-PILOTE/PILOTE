import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import 'school_geocoder_provider.dart';

// ─── Centroïdes départementaux — 15 départements (réforme oct. 2024) ─────────
// Sources : capitales officielles + OSM places. Les 3 nouveaux (Congo-Oubangui,
// Djoué-Léfini, Nkéni-Alima) utilisent les coordonnées de leur chef-lieu.
const Map<String, LatLng> _deptCoords = {
  'Brazzaville':    LatLng(-4.2634, 15.2429),
  'Pointe-Noire':   LatLng(-4.7761, 11.8635),
  'Bouenza':        LatLng(-4.1528, 13.5469),
  'Cuvette':        LatLng(-0.4874, 15.9010),
  'Cuvette-Ouest':  LatLng(-0.8705, 14.8175),
  'Kouilou':        LatLng(-4.4600, 11.8500),
  'Lékoumou':       LatLng(-3.6833, 13.3500),
  'Likouala':       LatLng(1.6167,  18.0667),
  'Niari':          LatLng(-4.2000, 12.6833),
  'Plateaux':       LatLng(-2.5431, 14.7578),
  'Sangha':         LatLng(1.6133,  16.0497),
  'Pool':           LatLng(-4.3517, 14.7644),
  // Nouveaux départements (loi du 8 octobre 2024)
  'Congo-Oubangui': LatLng(-1.2259, 16.7947), // chef-lieu : Mossaka
  'Nkéni-Alima':   LatLng(-1.8710, 15.8780),  // chef-lieu : Gamboma
  'Djoué-Léfini':  LatLng(-3.5851, 15.5174),  // chef-lieu : Odziba
};

// Centre géographique réel de la République du Congo (nord/sud : -5.2→3.8 → mid -0.7)
const adminCongoCenter = LatLng(-0.7, 15.3);

/// Chefs-lieux départementaux = principales agglomérations du Congo.
/// Données géographiques réelles (centroïdes officiels) — sert de référence
/// pour le calcul de distance école → agglomération principale.
const Map<String, LatLng> adminMajorAgglomerations = _deptCoords;

// ─── Modèles ────────────────────────────────────────────────────────────────
class AdminSchoolPin {
  const AdminSchoolPin({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    required this.students,
    this.city,
    this.department,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.locationCapturedAt,
  });
  final String id;
  final String name;
  final String type;
  final bool isActive;
  final int students;
  final String? city;
  final String? department;
  final double? latitude;
  final double? longitude;
  final String? locationSource; // 'gps' | 'geocoded' | 'manual'
  final DateTime? locationCapturedAt;

  bool get hasGps => latitude != null && longitude != null;
  LatLng? get gpsCoords => hasGps ? LatLng(latitude!, longitude!) : null;
}

class AdminProjectPin {
  const AdminProjectPin({
    required this.id,
    required this.name,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.schoolType,
    this.department,
    this.city,
    this.budgetXaf,
    this.beneficiariesEst,
    this.priority = 'moyenne',
    this.description,
    this.comments,
    this.schoolId,
    this.createdAt,
  });
  final String id;
  final String name;
  final String status; // etude|validation|budgetisation|construction|acheve
  final double latitude;
  final double longitude;
  final String? schoolType;
  final String? department;
  final String? city;
  final int? budgetXaf;
  final int? beneficiariesEst;
  final String priority; // haute|moyenne|basse
  final String? description;
  final String? comments;
  final String? schoolId;
  final DateTime? createdAt;

  LatLng get coords => LatLng(latitude, longitude);
}

class AdminDeptEntry {
  const AdminDeptEntry({
    required this.dept,
    required this.coords,
    required this.schoolCount,
    required this.studentCount,
    required this.activeCount,
    required this.schools,
  });
  final String dept;
  final LatLng coords;
  final int schoolCount;
  final int studentCount;
  final int activeCount;
  final List<AdminSchoolPin> schools;
}

class AdminRegionalData {
  const AdminRegionalData({
    required this.depts,
    required this.allDepts,
    required this.gpsSchools,
    required this.totalSchools,
    required this.totalStudents,
    required this.coveredDepts,
    required this.activeSchools,
  });
  /// Écoles SANS GPS, agrégées par département → sert UNIQUEMENT aux bulles
  /// « Pôles » de la carte (les écoles géolocalisées ont leur propre pin).
  final List<AdminDeptEntry> depts;
  /// TOUTES les écoles (GPS + non-GPS) agrégées par département → KPI,
  /// analytique et rapport PDF. Sans cela, géolocaliser les écoles vidait la
  /// répartition départementale et mettait « Départements couverts » à 0.
  final List<AdminDeptEntry> allDepts;
  final List<AdminSchoolPin> gpsSchools;  // écoles avec GPS, positionnées individuellement
  final int totalSchools;
  final int totalStudents;
  final int coveredDepts;
  final int activeSchools;

  int get gpsCount   => gpsSchools.length;
  int get noGpsCount => totalSchools - gpsCount;

  static const empty = AdminRegionalData(
    depts: [], allDepts: [], gpsSchools: [],
    totalSchools: 0, totalStudents: 0,
    coveredDepts: 0, activeSchools: 0,
  );
}

/// Libellé de département d'un pin (« Non précisé » si absent).
String deptKeyOf(AdminSchoolPin p) {
  final d = p.department;
  return (d == null || d.isEmpty) ? 'Non précisé' : d;
}

/// Agrège une liste de pins par département, triée par nombre d'écoles décroissant.
List<AdminDeptEntry> buildDeptEntries(Iterable<AdminSchoolPin> pins) {
  final byDept = <String, List<AdminSchoolPin>>{};
  for (final p in pins) {
    byDept.putIfAbsent(deptKeyOf(p), () => []).add(p);
  }
  return byDept.entries.map((e) {
    final list = e.value;
    return AdminDeptEntry(
      dept:         e.key,
      coords:       _resolveCoords(e.key),
      schoolCount:  list.length,
      studentCount: list.fold<int>(0, (a, p) => a + p.students),
      activeCount:  list.where((p) => p.isActive).length,
      schools:      list,
    );
  }).toList()
    ..sort((a, b) => b.schoolCount.compareTo(a.schoolCount));
}

/// Nombre de départements réellement couverts (hors « Non précisé »).
int countCoveredDepts(List<AdminDeptEntry> allDepts) =>
    allDepts.where((d) => d.dept != 'Non précisé').length;

// ─── Provider principal (écoles + effectifs) ────────────────────────────────
final adminRegionalProvider =
    FutureProvider.autoDispose<AdminRegionalData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  if (groupId == null) return AdminRegionalData.empty;

  // Realtime : une école créée/modifiée (ou un effectif qui bouge) rafraîchit
  // la carte sans action manuelle — même depuis une autre session.
  Timer? debounce;
  try {
    final channel = client.channel('admin_regional_$groupId');
    for (final t in ['schools', 'students']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
        },
      );
    }
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Timeout défensif : sans cela, un réseau lent/HS bloquerait le provider
  // indéfiniment. La carte territoriale s'affiche de toute façon sans attendre
  // (cf. AdminRegionalView) ; ici on échoue proprement plutôt que de pendre.
  final results = await Future.wait([
    client
        .from('schools')
        .select('id, name, school_type, department, city, is_active, '
                'latitude, longitude, location_source, location_captured_at')
        .eq('group_id', groupId),
    client
        .from('students')
        .select('school_id')
        .eq('group_id', groupId)
        .eq('is_active', true),
  ]).timeout(const Duration(seconds: 20));

  final schools  = results[0] as List;
  final students = results[1] as List;

  final Map<String, int> studentsBySchool = {};
  for (final st in students) {
    final sid = (st as Map)['school_id'] as String?;
    if (sid != null) {
      studentsBySchool[sid] = (studentsBySchool[sid] ?? 0) + 1;
    }
  }

  final List<AdminSchoolPin> gpsSchools = [];
  final List<AdminSchoolPin> allPins    = [];
  final Map<String, List<AdminSchoolPin>> pinsByDept = {};

  for (final s in schools) {
    final m   = s as Map;
    final id  = m['id'] as String;
    // num?.toDouble() et non `as double?` : une coordonnée sans décimale arrive
    // en int via JSON → un cast direct en double planterait la carte entière.
    final lat = (m['latitude']  as num?)?.toDouble();
    final lng = (m['longitude'] as num?)?.toDouble();
    final capRaw = m['location_captured_at'] as String?;
    final pin = AdminSchoolPin(
      id:                 id,
      name:               m['name'] as String? ?? '—',
      type:               m['school_type'] as String? ?? 'prive',
      isActive:           m['is_active'] as bool? ?? true,
      city:               m['city'] as String?,
      department:         (m['department'] as String?)?.trim(),
      latitude:           lat,
      longitude:          lng,
      locationSource:     m['location_source'] as String?,
      locationCapturedAt: capRaw != null ? DateTime.tryParse(capRaw) : null,
      students:           studentsBySchool[id] ?? 0,
    );

    allPins.add(pin);
    if (pin.hasGps) {
      gpsSchools.add(pin);
    } else {
      pinsByDept.putIfAbsent(deptKeyOf(pin), () => []).add(pin);
    }
  }

  // Bulles carte : écoles SANS GPS uniquement (les GPS ont leur pin propre).
  final depts = buildDeptEntries(pinsByDept.values.expand((e) => e));
  // KPI / analytique / PDF : TOUTES les écoles.
  final allDepts = buildDeptEntries(allPins);

  return AdminRegionalData(
    depts:         depts,
    allDepts:      allDepts,
    gpsSchools:    gpsSchools,
    totalSchools:  schools.length,
    totalStudents: students.length,
    coveredDepts:  countCoveredDepts(allDepts),
    activeSchools: schools.where((s) => (s as Map)['is_active'] as bool? ?? true).length,
  );
});

// ─── Provider projets (indépendant → invalidation granulaire) ───────────────
final adminProjectsProvider =
    FutureProvider.autoDispose<List<AdminProjectPin>>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  if (groupId == null) return [];

  final rows = await client
      .from('school_projects')
      .select()
      .eq('group_id', groupId)
      .order('created_at', ascending: false);

  return (rows as List).map((r) {
    final m = r as Map;
    final createdRaw = m['created_at'] as String?;
    return AdminProjectPin(
      id:               m['id'] as String,
      name:             m['name'] as String,
      status:           m['status'] as String? ?? 'etude',
      latitude:         (m['latitude'] as num).toDouble(),
      longitude:        (m['longitude'] as num).toDouble(),
      schoolType:       m['school_type'] as String?,
      department:       m['department'] as String?,
      city:             m['city'] as String?,
      budgetXaf:        (m['budget_xaf'] as num?)?.toInt(),
      beneficiariesEst: (m['beneficiaries_est'] as num?)?.toInt(),
      priority:         m['priority'] as String? ?? 'moyenne',
      description:      m['description'] as String?,
      comments:         m['comments'] as String?,
      schoolId:         m['school_id'] as String?,
      createdAt:        createdRaw != null ? DateTime.tryParse(createdRaw) : null,
    );
  }).toList();
});

// ─── Service CRUD projets + GPS écoles ──────────────────────────────────────
class AdminProjectService {
  AdminProjectService(this._client, this._groupId);
  final SupabaseClient _client;
  final String _groupId;

  Future<void> createProject({
    required String name,
    required double latitude,
    required double longitude,
    required String status,
    String? description,
    String? schoolType,
    String? department,
    String? city,
    int? budgetXaf,
    int? beneficiariesEst,
    String priority = 'moyenne',
    String? comments,
  }) async {
    await _client.from('school_projects').insert({
      'group_id':          _groupId,
      'name':              name,
      'latitude':          latitude,
      'longitude':         longitude,
      'status':            status,
      'description':       description,
      'school_type':       schoolType,
      'department':        department,
      'city':              city,
      'budget_xaf':        budgetXaf,
      'beneficiaries_est': beneficiariesEst,
      'priority':          priority,
      'comments':          comments,
      'created_by':        _client.auth.currentUser?.id,
    });
  }

  Future<void> updateProject({
    required String id,
    required String name,
    required String status,
    String? description,
    String? schoolType,
    String? department,
    String? city,
    int? budgetXaf,
    int? beneficiariesEst,
    String priority = 'moyenne',
    String? comments,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{
      'name':              name,
      'status':            status,
      'description':       description,
      'school_type':       schoolType,
      'department':        department,
      'city':              city,
      'budget_xaf':        budgetXaf,
      'beneficiaries_est': beneficiariesEst,
      'priority':          priority,
      'comments':          comments,
    };
    if (latitude != null)  data['latitude']  = latitude;
    if (longitude != null) data['longitude'] = longitude;
    await _client.from('school_projects').update(data).eq('id', id);
  }

  Future<void> deleteProject(String id) async {
    await _client.from('school_projects').delete().eq('id', id);
  }

  Future<void> patchSchoolGps({
    required String schoolId,
    required double latitude,
    required double longitude,
    String source = 'manual',
  }) async {
    await _client.from('schools').update({
      'latitude':             latitude,
      'longitude':            longitude,
      'location_source':      source,
      'location_captured_at': DateTime.now().toIso8601String(),
    }).eq('id', schoolId);
  }
}

final adminProjectServiceProvider =
    Provider.autoDispose<AdminProjectService>((ref) {
  final client  = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  return AdminProjectService(client, profile?.groupId ?? '');
});

// ─── Backfill GPS : géocodage de masse des écoles sans position ──────────────
/// Géocode les écoles du groupe sans GPS mais avec une ville connue
/// (`congo_places.json`). Écrit `location_source='geocoded'` et retourne le
/// nombre d'écoles corrigées. Rafraîchit la carte à la fin.
final geocodeMissingProvider =
    Provider.autoDispose<Future<int> Function()>((ref) {
  return () async {
    // Attendre le chargement de l'asset localités (sinon géocodage vide au démarrage).
    final places = await ref.read(congoPlacesProvider.future);
    final data   = await ref.read(adminRegionalProvider.future);
    final svc    = ref.read(adminProjectServiceProvider);
    // Les écoles sans GPS vivent dans les agrégats départementaux.
    final noGps = data.depts.expand((d) => d.schools).where((s) => !s.hasGps);
    var fixed = 0;
    for (final s in noGps) {
      final coords = geocodeCity(places, s.city);
      if (coords == null) continue;
      await svc.patchSchoolGps(
        schoolId:  s.id,
        latitude:  coords.latitude,
        longitude: coords.longitude,
        source:    'geocoded',
      );
      fixed++;
    }
    if (fixed > 0) ref.invalidate(adminRegionalProvider);
    return fixed;
  };
});

// ─── Utilitaires ─────────────────────────────────────────────────────────────
LatLng _resolveCoords(String dept) {
  if (_deptCoords.containsKey(dept)) return _deptCoords[dept]!;
  for (final entry in _deptCoords.entries) {
    if (dept.toLowerCase().contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(dept.toLowerCase())) {
      return entry.value;
    }
  }
  return adminCongoCenter;
}
