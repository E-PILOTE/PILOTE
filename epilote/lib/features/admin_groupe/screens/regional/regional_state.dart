part of '../admin_regional_view.dart';

// ─── State providers ────────────────────────────────────────────────────────

// Sélection unique sur la carte. Un type scellé garantit au niveau du type
// qu'UNE SEULE entité est sélectionnée à la fois (département XOR école XOR
// projet) : impossible d'en avoir deux actives, et un clic = une seule
// écriture au lieu de remettre deux providers à zéro à chaque fois.
sealed class RegionalSelection {
  const RegionalSelection();
}

class SelectionNone extends RegionalSelection {
  const SelectionNone();
}

class SelectionDept extends RegionalSelection {
  const SelectionDept(this.dept);
  final AdminDeptEntry dept;
}

class SelectionSchool extends RegionalSelection {
  const SelectionSchool(this.school);
  final AdminSchoolPin school;
}

class SelectionProject extends RegionalSelection {
  const SelectionProject(this.project);
  final AdminProjectPin project;
}

extension RegionalSelectionX on RegionalSelection {
  AdminDeptEntry? get deptOrNull => switch (this) {
        SelectionDept(:final dept) => dept,
        _ => null,
      };
  AdminSchoolPin? get schoolOrNull => switch (this) {
        SelectionSchool(:final school) => school,
        _ => null,
      };
  AdminProjectPin? get projectOrNull => switch (this) {
        SelectionProject(:final project) => project,
        _ => null,
      };
}

// Mode d'affichage de la Vue régionale : carte interactive ou tableau analytique.
enum RegionalViewMode { map, table }
final _regionalModeProv =
    StateProvider.autoDispose<RegionalViewMode>((ref) => RegionalViewMode.map);

final _selectionProv = StateProvider.autoDispose<RegionalSelection>(
    (ref) => const SelectionNone());
final _placementModeProv =
    StateProvider.autoDispose<bool>((ref) => false);
final _pendingProjectCoordsProv =
    StateProvider.autoDispose<LatLng?>((ref) => null);

// Style de fond cartographique (OSM standard / satellite ESRI / hybride)
enum _TileStyle { standard, satellite, hybrid }
final _tileStyleProv =
    StateProvider.autoDispose<_TileStyle>((ref) => _TileStyle.standard);

final _showMaskLayerProv     = StateProvider.autoDispose<bool>((ref) => true);
final _showGpsLayerProv      = StateProvider.autoDispose<bool>((ref) => true);
final _showDeptLayerProv     = StateProvider.autoDispose<bool>((ref) => true);
final _showProjLayerProv     = StateProvider.autoDispose<bool>((ref) => true);
final _showPolygonsLayerProv = StateProvider.autoDispose<bool>((ref) => true);
// Villes + bourgs (city/town) : actif par défaut
final _showCitiesLayerProv   = StateProvider.autoDispose<bool>((ref) => true);
// Villages/hameaux/localités : actif par défaut — ~1346 localités embarquées
// (CircleLayer léger à zoom national, étiquettes à zoom ≥ 9.5)
final _showVillagesLayerProv = StateProvider.autoDispose<bool>((ref) => true);
// Réseau routier OSM (trunk/primary/secondary/tertiary) — OFF par défaut (chargement ~15 s)
final _showRoadsLayerProv    = StateProvider.autoDispose<bool>((ref) => false);

// Dimension de coloration des pins écoles : par type d'établissement (défaut)
// ou par charge pédagogique (élèves/classe). Tier 4.
enum _PinColorMode { type, load, occupancy }
final _pinColorModeProv =
    StateProvider.autoDispose<_PinColorMode>((ref) => _PinColorMode.type);

// Rectangle couvrant tout le globe — anneau extérieur du masque géographique.
// Le « trou » (frontière du Congo) laisse apparaître le pays en clair tandis
// que tout l'extérieur est assombri → la carte se concentre sur le Congo.
const List<LatLng> _kWorldRect = [
  LatLng(-85, -180),
  LatLng(-85, 180),
  LatLng(85, 180),
  LatLng(85, -180),
];

// ─── Filtre carte ───────────────────────────────────────────────────────────
class _RegionalFilter {
  const _RegionalFilter({this.type, this.activeOnly = false});
  final String? type;
  final bool activeOnly;
  bool get isDefault => type == null && !activeOnly;
}

final _regionalFilterProv =
    StateProvider.autoDispose<_RegionalFilter>((ref) => const _RegionalFilter());

AdminRegionalData _applyFilter(AdminRegionalData data, _RegionalFilter f) {
  if (f.isDefault) return data;

  // GPS schools filter
  final gpsFiltered = data.gpsSchools.where((s) {
    if (f.type != null && s.type != f.type) return false;
    if (f.activeOnly && !s.isActive) return false;
    return true;
  }).toList();

  // Dept schools filter (existing logic)
  final depts = <AdminDeptEntry>[];
  var totSchools = 0, totStudents = 0, totActive = 0;
  for (final d in data.depts) {
    final pins = d.schools.where((p) {
      if (f.type != null && p.type != f.type) return false;
      if (f.activeOnly && !p.isActive) return false;
      return true;
    }).toList();
    if (pins.isEmpty) continue;
    final stu = pins.fold<int>(0, (a, p) => a + p.students);
    final act = pins.where((p) => p.isActive).length;
    depts.add(AdminDeptEntry(
      dept: d.dept, coords: d.coords,
      schoolCount: pins.length, studentCount: stu,
      activeCount: act, schools: pins,
    ));
    totSchools += pins.length;
    totStudents += stu;
    totActive += act;
  }
  depts.sort((a, b) => b.schoolCount.compareTo(a.schoolCount));

  final gpsStu    = gpsFiltered.fold<int>(0, (a, s) => a + s.students);
  final gpsActive = gpsFiltered.where((s) => s.isActive).length;

  return AdminRegionalData(
    depts:         depts,
    gpsSchools:    gpsFiltered,
    totalSchools:  totSchools + gpsFiltered.length,
    totalStudents: totStudents + gpsStu,
    coveredDepts:  depts.length,
    activeSchools: totActive + gpsActive,
  );
}

