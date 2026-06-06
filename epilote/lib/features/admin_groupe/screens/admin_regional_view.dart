import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_geo_provider.dart';
import '../providers/admin_regional_provider.dart';
import '../services/regional_pdf_service.dart';
import '../widgets/admin_ui.dart';
import '../widgets/mapillary_viewer.dart';

const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kOrange = Color(0xFFFF6B35);

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
// Villages : actif par défaut — CircleLayer léger (253 points, 2.5 px)
final _showVillagesLayerProv = StateProvider.autoDispose<bool>((ref) => true);
// Réseau routier OSM (trunk/primary/secondary/tertiary) — OFF par défaut (chargement ~15 s)
final _showRoadsLayerProv    = StateProvider.autoDispose<bool>((ref) => false);

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

// ─── Entrée principale ──────────────────────────────────────────────────────
class AdminRegionalView extends ConsumerWidget {
  const AdminRegionalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La carte territoriale s'affiche IMMÉDIATEMENT (assets géo embarqués),
    // sans jamais attendre les données écoles (Supabase). Les marqueurs écoles
    // se superposent dès que les données arrivent ; en cas de lenteur ou
    // d'erreur réseau, la carte du Congo reste visible — jamais d'écran vide.
    final async = ref.watch(adminRegionalProvider);
    return _MapLayout(
      data: async.valueOrNull ?? AdminRegionalData.empty,
      dataLoading: async.isLoading,
      dataError: async.hasError ? '${async.error}' : null,
    );
  }
}

// ─── Layout 3 colonnes ──────────────────────────────────────────────────────
class _MapLayout extends ConsumerWidget {
  const _MapLayout({
    required this.data,
    this.dataLoading = false,
    this.dataError,
  });
  final AdminRegionalData data;
  final bool dataLoading;       // données écoles en cours de chargement
  final String? dataError;      // message d'erreur réseau (carte reste visible)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter    = ref.watch(_regionalFilterProv);
    final view      = _applyFilter(data, filter);
    final selection    = ref.watch(_selectionProv);
    final selectedRaw  = selection.deptOrNull;
    final selectedGps  = selection.schoolOrNull;
    final selectedProj = selection.projectOrNull;
    final isPlacement  = ref.watch(_placementModeProv);

    // Dialog de création projet déclenché par le tap sur la carte
    ref.listen<LatLng?>(_pendingProjectCoordsProv, (_, coords) {
      if (coords == null) return;
      ref.read(_pendingProjectCoordsProv.notifier).state = null;
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => _ProjectFormDialog(
          initialCoords: coords,
          onSaved: () => ref.invalidate(adminProjectsProvider),
        ),
      );
    });

    // Résolution du département sélectionné sur la vue filtrée
    AdminDeptEntry? selected;
    if (selectedRaw != null) {
      for (final d in view.depts) {
        if (d.dept == selectedRaw.dept) {
          selected = d;
          break;
        }
      }
    }

    return LayoutBuilder(builder: (context, c) {
      final showLeft  = c.maxWidth >= 780;
      final showRight = c.maxWidth >= 1060;

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              if (showLeft) ...[
                SizedBox(
                  width: 280,
                  child: Container(
                    color: kCardBg,
                    child: Column(
                      children: [
                        // Stats + filtres + couches + liste défilent ensemble :
                        // robuste à toute hauteur de fenêtre (plus d'overflow).
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _GlobalStats(data: view),
                              const Divider(height: 1, color: kBorder),
                              const _FilterBar(),
                              const Divider(height: 1, color: kBorder),
                              const _LayerToggleBar(),
                              const Divider(height: 1, color: kBorder),
                              _DeptList(data: view, embedded: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: kBorder),
                        _RegionalExportBar(data: data),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: kBorder),
              ],
              Expanded(
                child: Stack(
                  children: [
                    _OsmMap(data: view),
                    if (!showLeft)
                      const Positioned(
                          top: 12, left: 12, child: _FilterBar(floating: true)),
                    const Positioned(left: 12, bottom: 12, child: _MapLegend()),
                    // Statut données écoles — non bloquant : la carte reste
                    // affichée pendant le chargement Supabase ou en cas d'erreur.
                    if (!isPlacement &&
                        (dataLoading ||
                            dataError != null ||
                            data.totalSchools == 0))
                      Positioned(
                        top: 12, left: 0, right: 0,
                        child: Center(
                          child: _MapDataStatus(
                            loading: dataLoading,
                            error: dataError,
                          ),
                        ),
                      ),
                    // Bannière mode placement
                    if (isPlacement)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          color: _kOrange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: const Row(children: [
                            Icon(Icons.touch_app_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Appuyez sur la carte pour placer le projet',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    // Sélecteur de fond flottant (visible même sans panneau gauche)
                    const Positioned(
                      bottom: 48, right: 12,
                      child: _MapTileSwitcher(),
                    ),
                    // FABs (Refresh + Nouveau projet)
                    Positioned(
                      top: 12, right: 12,
                      child: Column(children: [
                        FloatingActionButton.small(
                          heroTag: 'admin_refresh_map',
                          backgroundColor: kNavy,
                          tooltip: 'Actualiser',
                          onPressed: () {
                            ref.invalidate(adminRegionalProvider);
                            ref.invalidate(adminProjectsProvider);
                          },
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'admin_add_project',
                          backgroundColor: isPlacement ? kRed : _kOrange,
                          tooltip: isPlacement
                              ? 'Annuler le placement'
                              : 'Nouveau projet scolaire',
                          onPressed: () => ref
                              .read(_placementModeProv.notifier)
                              .state = !isPlacement,
                          child: Icon(
                            isPlacement
                                ? Icons.close_rounded
                                : Icons.add_location_alt_rounded,
                            color: Colors.white, size: 18,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              if (showRight) ...[
                const VerticalDivider(width: 1, color: kBorder),
                SizedBox(
                  width: 300,
                  child: () {
                    if (selectedProj != null) {
                      return SingleChildScrollView(
                        child: _ProjectDetailPanel(
                          project: selectedProj,
                          onEdit: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black54,
                              builder: (_) => _ProjectFormDialog(
                                initialCoords: selectedProj.coords,
                                project: selectedProj,
                                onSaved: () {
                                  ref.invalidate(adminProjectsProvider);
                                  ref.read(_selectionProv.notifier).state =
                                      const SelectionNone();
                                },
                              ),
                            );
                          },
                          onDelete: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Supprimer le projet ?'),
                                content: Text(
                                    'Cette action est irréversible.\n« ${selectedProj.name} »'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: kRed),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Supprimer',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ref
                                  .read(adminProjectServiceProvider)
                                  .deleteProject(selectedProj.id);
                              ref.invalidate(adminProjectsProvider);
                              ref.read(_selectionProv.notifier).state =
                                  const SelectionNone();
                            }
                          },
                        ),
                      );
                    }
                    if (selectedGps != null) {
                      return SingleChildScrollView(
                          child: _GpsSchoolDetailPanel(school: selectedGps));
                    }
                    if (selected != null) {
                      return SingleChildScrollView(
                          child: _DeptDetail(dept: selected));
                    }
                    return SingleChildScrollView(
                        child: _RegionalAnalytics(data: view));
                  }(),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ─── Filtres type d'établissement ───────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  const _FilterBar({this.floating = false});
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f        = ref.watch(_regionalFilterProv);
    final notifier = ref.read(_regionalFilterProv.notifier);
    void setType(String? t) =>
        notifier.state = _RegionalFilter(type: t, activeOnly: f.activeOnly);
    void toggleActive() =>
        notifier.state = _RegionalFilter(type: f.type, activeOnly: !f.activeOnly);

    final chips = Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _FilterChip(
            label: 'Tous', active: f.type == null,
            color: kNavy, onTap: () => setType(null)),
        _FilterChip(
            label: 'Public', active: f.type == 'public',
            color: _kBlue, onTap: () => setType('public')),
        _FilterChip(
            label: 'Privé', active: f.type == 'prive',
            color: kGreen, onTap: () => setType('prive')),
        _FilterChip(
            label: 'Mixte', active: f.type == 'mixte',
            color: _kPurple, onTap: () => setType('mixte')),
        _FilterChip(
            label: 'Actives',
            icon: Icons.check_circle_rounded,
            active: f.activeOnly,
            color: kAccent,
            onTap: toggleActive),
      ],
    );

    if (floating) {
      return Container(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: chips,
      );
    }

    return Container(
      width: double.infinity,
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 13, color: kTextMuted),
              const SizedBox(width: 6),
              const Text('FILTRER',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 1.0)),
              const Spacer(),
              if (!f.isDefault)
                _FilterChip(
                    label: 'Réinit.',
                    icon: Icons.close_rounded,
                    active: false,
                    color: kRed,
                    onTap: () =>
                        notifier.state = const _RegionalFilter()),
            ],
          ),
          const SizedBox(height: 8),
          chips,
        ],
      ),
    );
  }
}

// ─── Toggles de couches ──────────────────────────────────────────────────────
class _LayerToggleBar extends ConsumerWidget {
  const _LayerToggleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileStyle  = ref.watch(_tileStyleProv);
    final showMask   = ref.watch(_showMaskLayerProv);
    final showGps    = ref.watch(_showGpsLayerProv);
    final showDept   = ref.watch(_showDeptLayerProv);
    final showProj   = ref.watch(_showProjLayerProv);
    final showPolygons = ref.watch(_showPolygonsLayerProv);
    final showCities   = ref.watch(_showCitiesLayerProv);
    final showVillages = ref.watch(_showVillagesLayerProv);
    final showRoads    = ref.watch(_showRoadsLayerProv);

    const sectionLabel = TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700,
        color: kTextMuted, letterSpacing: 1.0);

    return Container(
      width: double.infinity,
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fond de carte ──────────────────────────────────────────────────
          const Row(children: [
            Icon(Icons.travel_explore_rounded, size: 13, color: kTextMuted),
            SizedBox(width: 6),
            Text('FOND DE CARTE', style: sectionLabel),
          ]),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(children: [
              _TileBtn(
                  label: 'Carte',
                  icon: Icons.map_outlined,
                  active: tileStyle == _TileStyle.standard,
                  onTap: () => ref.read(_tileStyleProv.notifier).state =
                      _TileStyle.standard,
                  first: true),
              Container(width: 1, height: 28, color: kBorder),
              _TileBtn(
                  label: 'Satellite',
                  icon: Icons.satellite_alt_rounded,
                  active: tileStyle == _TileStyle.satellite,
                  onTap: () => ref.read(_tileStyleProv.notifier).state =
                      _TileStyle.satellite),
              Container(width: 1, height: 28, color: kBorder),
              _TileBtn(
                  label: 'Hybride',
                  icon: Icons.layers_rounded,
                  active: tileStyle == _TileStyle.hybrid,
                  onTap: () => ref.read(_tileStyleProv.notifier).state =
                      _TileStyle.hybrid,
                  last: true),
            ]),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 8),
          // ── Couches de données ──────────────────────────────────────────────
          const Row(children: [
            Icon(Icons.layers_rounded, size: 13, color: kTextMuted),
            SizedBox(width: 6),
            Text('COUCHES', style: sectionLabel),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 5, runSpacing: 5, children: [
            _FilterChip(
                label: 'Congo seul',
                icon: Icons.center_focus_strong_rounded,
                active: showMask,
                color: kRed,
                onTap: () =>
                    ref.read(_showMaskLayerProv.notifier).state = !showMask),
            _FilterChip(
                label: 'Depts',
                icon: Icons.crop_square_rounded,
                active: showPolygons,
                color: kNavy,
                onTap: () =>
                    ref.read(_showPolygonsLayerProv.notifier).state = !showPolygons),
            _FilterChip(
                label: 'Pôles',
                icon: Icons.map_rounded,
                active: showDept,
                color: _kBlue,
                onTap: () =>
                    ref.read(_showDeptLayerProv.notifier).state = !showDept),
            _FilterChip(
                label: 'GPS',
                icon: Icons.gps_fixed_rounded,
                active: showGps,
                color: kGreen,
                onTap: () =>
                    ref.read(_showGpsLayerProv.notifier).state = !showGps),
            _FilterChip(
                label: 'Projets',
                icon: Icons.business_center_rounded,
                active: showProj,
                color: _kOrange,
                onTap: () =>
                    ref.read(_showProjLayerProv.notifier).state = !showProj),
            _FilterChip(
                label: 'Villes',
                icon: Icons.location_city_rounded,
                active: showCities,
                color: _kBlue,
                onTap: () =>
                    ref.read(_showCitiesLayerProv.notifier).state = !showCities),
            _FilterChip(
                label: 'Villages',
                icon: Icons.holiday_village_rounded,
                active: showVillages,
                color: _kPurple,
                onTap: () =>
                    ref.read(_showVillagesLayerProv.notifier).state = !showVillages),
            _FilterChip(
                label: 'Routes',
                icon: Icons.route_rounded,
                active: showRoads,
                color: const Color(0xFFF59E0B),
                onTap: () {
                  ref.read(_showRoadsLayerProv.notifier).state = !showRoads;
                  // Déclenche le chargement la 1ère fois qu'on active
                  if (!showRoads) ref.read(congoRoadsProvider);
                }),
          ]),
        ],
      ),
    );
  }
}

// ─── Bouton sélection fond de carte ─────────────────────────────────────────
class _TileBtn extends StatelessWidget {
  const _TileBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.first = false,
    this.last = false,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 30,
            decoration: BoxDecoration(
              color: active ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.horizontal(
                left: first ? const Radius.circular(6) : Radius.zero,
                right: last ? const Radius.circular(6) : Radius.zero,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 12, color: active ? Colors.white : kTextMuted),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : kTextPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: active ? color : color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: active ? Colors.white : color),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : kTextMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sélecteur de fond flottant sur la carte ─────────────────────────────────
class _MapTileSwitcher extends ConsumerWidget {
  const _MapTileSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(_tileStyleProv);

    Widget btn(_TileStyle s, String label, IconData icon) {
      final active = style == s;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => ref.read(_tileStyleProv.notifier).state = s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: active ? kNavy : kCardBg.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 13, color: active ? Colors.white : kTextMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : kTextPrimary)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          btn(_TileStyle.standard,  'Carte',      Icons.map_outlined),
          Container(width: 1, height: 32, color: kBorder),
          btn(_TileStyle.satellite, 'Satellite',  Icons.satellite_alt_rounded),
          Container(width: 1, height: 32, color: kBorder),
          btn(_TileStyle.hybrid,    'Hybride',    Icons.layers_rounded),
        ]),
      ),
    );
  }
}

// Normalise un nom de département pour la correspondance OSM ↔ DB
// (accents, tirets, casse)
String _normDept(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ùûü]'), 'u')
    .replaceAll(RegExp(r'[^a-z]'), '');

// ─── Marqueur de lieu : ville / bourg / village ───────────────────────────────
// Hiérarchie visuelle :
//   city   → dot 11 px bleu ciel + étiquette blanche/navy (toujours visible)
//   town   → dot  7 px vert      + étiquette (visible à zoom ≥ 7)
//   village→ dot  4 px gris      + étiquette (visible à zoom ≥ 9.5)
class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({
    required this.name,
    required this.type,
    required this.onSatellite,
  });
  final String name;
  final String type;
  final bool onSatellite;

  @override
  Widget build(BuildContext context) {
    final isCity    = type == 'city';
    final isTown    = type == 'town';
    final dotColor  = isCity
        ? const Color(0xFF0EA5E9)   // bleu ciel
        : isTown
            ? const Color(0xFF10B981) // vert émeraude
            : const Color(0xFF94A3B8); // ardoise
    final dotSize   = isCity ? 11.0 : isTown ? 7.5 : 4.5;
    final fontSize  = isCity ? 9.0  : isTown ? 8.0  : 7.5;
    final fontW     = isCity ? FontWeight.w800 : FontWeight.w600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: Border.all(
                color: Colors.white,
                width: isCity ? 1.8 : 1.2),
            boxShadow: isCity
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 4, offset: const Offset(0, 1))]
                : isTown
                    ? [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 2)]
                    : null,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isCity ? 4 : 3,
              vertical: isCity ? 1.5 : 1),
          decoration: BoxDecoration(
            color: onSatellite
                ? Colors.black.withValues(alpha: isCity ? 0.75 : 0.62)
                : Colors.white.withValues(alpha: isCity ? 0.95 : 0.88),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 2)
            ],
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontW,
              color: onSatellite ? Colors.white : kNavy,
              letterSpacing: isCity ? 0.2 : 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Étiquette nom de département (centroïde géométrique réel) ───────────────
class _DeptLabel extends StatelessWidget {
  const _DeptLabel({required this.name, required this.onSatellite});
  final String name;
  final bool onSatellite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: onSatellite
              ? Colors.black.withValues(alpha: 0.62)
              : kNavy.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          name.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

// ─── Overlay chargement données géo (Overpass prend 15-90 s) ─────────────────
class _GeoLoadingOverlay extends StatelessWidget {
  const _GeoLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8)
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 1.8),
            ),
            SizedBox(width: 8),
            Text('Chargement des données cartographiques OSM…',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// ─── Légende ────────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    Widget circle(Color c, double s) => Container(
          width: s, height: s,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
    Widget sq(Color c, double s) => Container(
          width: s, height: s,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
    Widget colorBox(Color c, double alpha) => Container(
          width: 14, height: 10,
          decoration: BoxDecoration(
            color: c.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: c.withValues(alpha: alpha + 0.2), width: 1),
          ),
        );
    Widget row(Widget leading, String label) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            leading,
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 9, color: kTextPrimary)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LÉGENDE',
                style: TextStyle(
                    fontSize: 8.5, fontWeight: FontWeight.w800,
                    color: kTextMuted, letterSpacing: 1.0)),
            // Choroplèthe
            const SizedBox(height: 3),
            const Text('CHOROPLÈTHE',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            row(colorBox(kGreen,  0.13), '≥ 75 % actives'),
            row(colorBox(kNavy,   0.09), '40–74 %'),
            row(colorBox(_kOrange, 0.13), '< 40 %'),
            row(colorBox(kRed,    0.10), 'Aucune école'),
            // Écoles
            const SizedBox(height: 3),
            const Text('ÉCOLES & PROJETS',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            row(circle(kGreen, 11), 'École GPS (publique)'),
            row(circle(_kBlue, 11), 'École GPS (privée)'),
            row(sq(_kOrange, 10), 'Projet en cours'),
            row(sq(kGreen, 10), 'Projet achevé'),
            row(
              Row(mainAxisSize: MainAxisSize.min, children: [
                circle(kNavy, 8), const SizedBox(width: 2), circle(kNavy, 14),
              ]),
              'Taille ∝ élèves',
            ),
            // Localités
            const SizedBox(height: 3),
            const Text('LOCALITÉS',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            row(circle(const Color(0xFF0EA5E9), 10), 'Ville (toujours visible)'),
            row(circle(const Color(0xFF10B981),  8), 'Bourg (zoom ≥ 7)'),
            row(circle(const Color(0xFF94A3B8),  6), 'Village (zoom ≥ 9.5)'),
          ]),
    );
  }
}

// ─── Statistiques globales ──────────────────────────────────────────────────
class _GlobalStats extends StatelessWidget {
  const _GlobalStats({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kNavyDark, kNavy],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COUVERTURE DU GROUPE',
              style: TextStyle(color: Colors.white70, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Vue Régionale',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            _StatPill(
                value: '${data.coveredDepts}',
                label: 'Départ.',
                icon: Icons.map_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.totalSchools}',
                label: 'Écoles',
                icon: Icons.business_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(
                value: '${data.activeSchools}',
                label: 'Actives',
                icon: Icons.check_circle_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.totalStudents}',
                label: 'Élèves',
                icon: Icons.people_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(
                value: '${data.gpsCount}',
                label: 'GPS',
                icon: Icons.gps_fixed_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.noGpsCount}',
                label: 'Sans GPS',
                icon: Icons.gps_off_rounded),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.value, required this.label, required this.icon});
  final String value, label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: kAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 9)),
                  ]),
            ),
          ]),
        ),
      );
}

// ─── Export PDF officiel ─────────────────────────────────────────────────────
class _RegionalExportBar extends ConsumerStatefulWidget {
  const _RegionalExportBar({required this.data});
  final AdminRegionalData data;

  @override
  ConsumerState<_RegionalExportBar> createState() => _RegionalExportBarState();
}

class _RegionalExportBarState extends ConsumerState<_RegionalExportBar> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // .future : on s'assure d'avoir les projets (et pas un instantané vide)
      // même si l'utilisateur exporte avant la fin du 1er chargement.
      final projects = await ref.read(adminProjectsProvider.future);
      final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
          'Groupe scolaire';
      await RegionalPdfService.printReport(
        groupName: groupName,
        data: widget.data,
        projects: projects,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Export impossible : $e'), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _export,
          icon: _busy
              ? const SizedBox(
                  width: 15, height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: const Text('Rapport territorial (PDF)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

// ─── Liste des départements ─────────────────────────────────────────────────
class _DeptList extends ConsumerWidget {
  const _DeptList({required this.data, this.embedded = false});
  final AdminRegionalData data;

  /// Quand true : rendu non défilant (shrinkWrap) pour s'insérer dans une
  /// liste parente qui gère le défilement. Évite tout overflow vertical.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectionProv).deptOrNull;
    if (data.depts.isEmpty && data.gpsCount == 0) {
      final empty = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_alt_off_rounded,
              size: 26, color: kTextMuted.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          const Text('Aucun établissement\npour ce filtre',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      );
      return embedded ? empty : Center(child: empty);
    }

    final items = <Widget>[];

    // Section GPS
    if (data.gpsCount > 0) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          const Icon(Icons.gps_fixed_rounded, size: 11, color: kGreen),
          const SizedBox(width: 5),
          Text('GÉOLOCALISÉES (${data.gpsCount})',
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: kTextMuted, letterSpacing: 0.8)),
        ]),
      ));
      for (final school in data.gpsSchools) {
        final isSelected =
            ref.watch(_selectionProv).schoolOrNull?.id == school.id;
        items.add(InkWell(
          onTap: () {
            ref.read(_selectionProv.notifier).state =
                isSelected ? const SelectionNone() : SelectionSchool(school);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            color: isSelected
                ? kGreen.withValues(alpha: 0.06)
                : Colors.transparent,
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _typeColorForPin(school.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.school_rounded,
                    size: 12, color: _typeColorForPin(school.type)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(school.name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: kTextPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                          [school.city, school.department]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 9, color: kTextMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
              ),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: school.isActive ? kGreen : kRed,
                  shape: BoxShape.circle,
                ),
              ),
            ]),
          ),
        ));
      }
      if (data.depts.isNotEmpty) {
        items.add(const Divider(height: 1, color: kBorder));
      }
    }

    // Section départements
    if (data.depts.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          const Icon(Icons.map_outlined, size: 11, color: kNavy),
          const SizedBox(width: 5),
          Text('PAR DÉPARTEMENT (${data.depts.fold(0, (s, d) => s + d.schoolCount)})',
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: kTextMuted, letterSpacing: 0.8)),
        ]),
      ));
      for (var i = 0; i < data.depts.length; i++) {
        final dept = data.depts[i];
        final isSelected = selected?.dept == dept.dept;
        final rate =
            dept.schoolCount > 0 ? dept.activeCount / dept.schoolCount : 0.0;
        items.add(InkWell(
          onTap: () {
            ref.read(_selectionProv.notifier).state =
                isSelected ? const SelectionNone() : SelectionDept(dept);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: isSelected
                ? kNavy.withValues(alpha: 0.06)
                : Colors.transparent,
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: i < 3
                      ? kAccent.withValues(alpha: 0.15)
                      : kSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: i < 3
                                ? const Color(0xFFB45309)
                                : kTextMuted))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept.dept,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: kTextPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: rate.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: kSurface,
                          valueColor: AlwaysStoppedAnimation(
                              rate > 0.6 ? kGreen : kAccent),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('${dept.schoolCount} écoles · ${dept.studentCount} élèves',
                          style: const TextStyle(
                              fontSize: 9, color: kTextMuted)),
                    ]),
              ),
            ]),
          ),
        ));
      }
    }

    if (embedded) {
      // Pas de défilement propre : la ListView parente s'en charge.
      return Column(mainAxisSize: MainAxisSize.min, children: items);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: items,
    );
  }
}

// ─── Carte OSM ──────────────────────────────────────────────────────────────
class _OsmMap extends ConsumerStatefulWidget {
  const _OsmMap({required this.data});
  final AdminRegionalData data;

  @override
  ConsumerState<_OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends ConsumerState<_OsmMap> {
  final _mapController = MapController();
  double _zoom = 6.0;

  // Ne déclenche un rebuild que quand on franchit un seuil de zoom :
  //  < 7   → villes seules avec étiquette
  //  7–9.5 → + bourgs avec étiquette
  //  ≥ 9.5 → + villages avec étiquette
  void _onZoom(MapCamera camera, bool _) {
    final z = camera.zoom;
    final cross =
        (_zoom < 7.0) != (z < 7.0) || (_zoom < 9.5) != (z < 9.5);
    _zoom = z;
    if (cross && mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Marker> _buildDeptMarkers(
      AdminRegionalData view, AdminDeptEntry? selected) {
    final maxStu = view.depts.fold<int>(
        1, (m, d) => d.studentCount > m ? d.studentCount : m);
    return view.depts.map((dept) {
      final isSelected = selected?.dept == dept.dept;
      final allInactive = dept.activeCount == 0 && dept.schoolCount > 0;
      final color = allInactive ? kRed : (isSelected ? kAccent : kNavy);
      final dia = _bubbleDiameter(dept.studentCount, maxStu);
      return Marker(
        point: dept.coords,
        width: isSelected ? 200 : (dia + 60).clamp(0.0, 200.0),
        height: dia + (isSelected ? 52 : 40),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            ref.read(_selectionProv.notifier).state =
                isSelected ? const SelectionNone() : SelectionDept(dept);
            _mapController.move(dept.coords, 7.0);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: dia, height: dia,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white, width: isSelected ? 2.5 : 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.40),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Text('${dept.schoolCount}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: dia < 38 ? 12 : 14,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              child: Text(
                  isSelected
                      ? '${dept.dept} · ${dept.studentCount} él.'
                      : dept.dept,
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: kTextPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }).toList();
  }

  List<Marker> _buildGpsMarkers(
      List<AdminSchoolPin> schools, AdminSchoolPin? selectedGps) {
    return schools.map((school) {
      final isSelected = selectedGps?.id == school.id;
      final color = _typeColorForPin(school.type);
      final size = isSelected ? 34.0 : 26.0;
      return Marker(
        point: school.gpsCoords!,
        width: isSelected ? 150 : 110,
        height: size + (isSelected ? 44 : 34),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            ref.read(_selectionProv.notifier).state =
                isSelected ? const SelectionNone() : SelectionSchool(school);
            if (!isSelected) _mapController.move(school.gpsCoords!, 10.0);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size, height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (school.isActive ? color : kRed)
                    .withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white, width: isSelected ? 2.5 : 2.0),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(Icons.school_rounded,
                  color: Colors.white, size: size * 0.46),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kBorder),
              ),
              child: Text(
                _truncate(school.name, isSelected ? 18 : 13),
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: kTextPrimary),
                maxLines: 1,
              ),
            ),
          ]),
        ),
      );
    }).toList();
  }

  List<Marker> _buildProjectMarkers(
      List<AdminProjectPin> projects, AdminProjectPin? selectedProj) {
    return projects.map((project) {
      final isSelected = selectedProj?.id == project.id;
      final color = _projectStatusColor(project.status);
      final size = isSelected ? 32.0 : 24.0;
      return Marker(
        point: project.coords,
        width: isSelected ? 150 : 110,
        height: size + (isSelected ? 44 : 34),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            ref.read(_selectionProv.notifier).state =
                isSelected ? const SelectionNone() : SelectionProject(project);
            if (!isSelected) _mapController.move(project.coords, 9.0);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size, height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: Colors.white, width: isSelected ? 2.5 : 2.0),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(_projectStatusIcon(project.status),
                  color: Colors.white, size: size * 0.46),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _truncate(project.name, isSelected ? 18 : 13),
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: Colors.white),
                maxLines: 1,
              ),
            ),
          ]),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selection    = ref.watch(_selectionProv);
    final selected     = selection.deptOrNull;
    final selectedGps  = selection.schoolOrNull;
    final selectedProj = selection.projectOrNull;
    final isPlacement  = ref.watch(_placementModeProv);
    final tileStyle        = ref.watch(_tileStyleProv);
    final showMask         = ref.watch(_showMaskLayerProv);
    final showGps          = ref.watch(_showGpsLayerProv);
    final showDept         = ref.watch(_showDeptLayerProv);
    final showProj         = ref.watch(_showProjLayerProv);
    final showPolygons     = ref.watch(_showPolygonsLayerProv);
    final showCities       = ref.watch(_showCitiesLayerProv);
    final showVillages     = ref.watch(_showVillagesLayerProv);
    final showRoads        = ref.watch(_showRoadsLayerProv);
    final projectsAsync    = ref.watch(adminProjectsProvider);
    final boundaryAsync    = ref.watch(congoBoundaryProvider);
    final polygonsAsync    = ref.watch(congoDepartmentsProvider);
    final placesAsync      = ref.watch(congoPlacesProvider);
    final roadsAsync       = showRoads ? ref.watch(congoRoadsProvider)
                                       : const AsyncData<List<CongoRoad>>([]);

    // Bloquer la carte uniquement pendant le chargement initial des assets.
    // Grâce au pré-chargement dans _Body, les assets sont déjà prêts (<100 ms)
    // quand l'utilisateur arrive sur cet onglet → pas de spinner visible.
    // En cas d'erreur (hasError) on laisse passer : la carte s'affiche sans masque
    // plutôt que de bloquer indéfiniment.
    if (boundaryAsync.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: kNavy, strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text(
              'Chargement de la carte…',
              style: TextStyle(fontSize: 13, color: kTextMuted),
            ),
          ],
        ),
      );
    }

    return Stack(children: [
      MouseRegion(
      cursor: isPlacement
          ? SystemMouseCursors.precise
          : MouseCursor.defer,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // Adapte automatiquement le zoom au Congo quelle que soit la taille
          // de l'écran — plus fiable que fixer un initialZoom statique.
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(
              const LatLng(-5.2, 11.0),
              const LatLng(3.8, 18.8),
            ),
            padding: const EdgeInsets.all(28),
          ),
          minZoom: 5.8,
          // Jusqu'à z19 : permet de descendre au niveau des toits et des ruelles
          // sur l'imagerie satellite (Brazzaville, Pointe-Noire…).
          maxZoom: 19,
          cameraConstraint: const CameraConstraint.unconstrained(),
          onPositionChanged: _onZoom,
          onTap: (_, latlng) {
            if (isPlacement) {
              ref.read(_placementModeProv.notifier).state = false;
              ref.read(_pendingProjectCoordsProv.notifier).state = latlng;
            } else {
              ref.read(_selectionProv.notifier).state = const SelectionNone();
            }
          },
        ),
        children: [
          // ── Fond cartographique ────────────────────────────────────────────
          // Standard : OpenStreetMap (ODbL)
          if (tileStyle == _TileStyle.standard)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.epilote.congo',
              maxZoom: 19,
            ),
          // Satellite : Esri World Imagery (usage libre, aucune clé API)
          if (tileStyle == _TileStyle.satellite ||
              tileStyle == _TileStyle.hybrid)
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.epilote.congo',
              maxNativeZoom: 19,
              maxZoom: 19,
            ),
          // Hybride : étiquettes + limites par-dessus le satellite
          if (tileStyle == _TileStyle.hybrid)
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.epilote.congo',
              maxNativeZoom: 18,
              maxZoom: 19,
            ),

          // ── Masque Congo ───────────────────────────────────────────────────
          // Rectangle monde avec le Congo découpé en « trou » → tout l'extérieur
          // est voilé, le pays reste en pleine luminosité + frontière tracée.
          // Couleur adaptée au fond : semi-opaque sur OSM, plus dense sur satellite.
          if (showMask)
            boundaryAsync.maybeWhen(
              data: (ring) => PolygonLayer(
                polygons: [
                  Polygon(
                    points: _kWorldRect,
                    holePointsList: [ring],
                    color: (tileStyle == _TileStyle.standard
                            ? const Color(0xFFEDF1F6)
                            : Colors.black)
                        .withValues(
                            alpha: tileStyle == _TileStyle.standard
                                ? 0.86
                                : 0.62),
                  ),
                  Polygon(
                    points: ring,
                    borderStrokeWidth: 2.5,
                    borderColor: tileStyle == _TileStyle.standard
                        ? kNavy.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Choroplèthe + frontières des 15 départements ─────────────────
          // Coloration : vert=actif / bleu=partiel / orange=inactif / gris=0 école
          if (showPolygons)
            polygonsAsync.maybeWhen(
              data: (osmDepts) {
                // Table de ratios d'activité : nom normalisé → ratio [0..1] ou -1
                final ratios = <String, double>{};
                for (final d in widget.data.depts) {
                  ratios[_normDept(d.dept)] = d.schoolCount > 0
                      ? d.activeCount / d.schoolCount
                      : 0.0;
                }
                return PolygonLayer(
                  polygons: osmDepts.map((d) {
                    final ratio = ratios[_normDept(d.name)] ?? -1.0;
                    final fillColor = ratio < 0
                        ? Colors.transparent
                        : ratio >= 0.75
                            ? kGreen.withValues(alpha: 0.13)
                            : ratio >= 0.4
                                ? kNavy.withValues(alpha: 0.09)
                                : ratio > 0
                                    ? _kOrange.withValues(alpha: 0.13)
                                    : kRed.withValues(alpha: 0.10);
                    return Polygon(
                      points: d.outline,
                      color: fillColor,
                      borderStrokeWidth: 1.5,
                      borderColor: (tileStyle == _TileStyle.standard
                              ? kNavy
                              : Colors.white)
                          .withValues(alpha: 0.55),
                    );
                  }).toList(),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          // ── Étiquettes départements ───────────────────────────────────────
          if (showPolygons)
            polygonsAsync.maybeWhen(
              data: (depts) => MarkerLayer(
                markers: depts.map((d) {
                  final labelW = d.name.length * 7.0 + 12;
                  return Marker(
                    point: d.centroid,
                    width: labelW.clamp(60, 130),
                    height: 20,
                    child: _DeptLabel(
                      name: d.name,
                      onSatellite: tileStyle != _TileStyle.standard,
                    ),
                  );
                }).toList(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Couche 1 : villes (9) — étiquette TOUJOURS visible ────────────
          if (showCities)
            placesAsync.maybeWhen(
              data: (places) => MarkerLayer(
                markers: places
                    .where((p) => p.type == 'city')
                    .map((p) => Marker(
                          point: p.coords,
                          width: (p.name.length * 6.5 + 18).clamp(70, 130),
                          height: 34,
                          child: _PlaceMarker(
                              name: p.name,
                              type: 'city',
                              onSatellite: tileStyle != _TileStyle.standard),
                        ))
                    .toList(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Couche 2 : bourgs (78) — étiquette à zoom ≥ 7 ──────────────
          if (showCities)
            placesAsync.maybeWhen(
              data: (places) {
                final towns = places.where((p) => p.type == 'town').toList();
                if (_zoom >= 7.0) {
                  // Zoom dept : étiquette visible
                  return MarkerLayer(
                    markers: towns
                        .map((p) => Marker(
                              point: p.coords,
                              width: (p.name.length * 5.5 + 14).clamp(50, 110),
                              height: 28,
                              child: _PlaceMarker(
                                  name: p.name,
                                  type: 'town',
                                  onSatellite: tileStyle != _TileStyle.standard),
                            ))
                        .toList(),
                  );
                }
                // Zoom national : cercle seul (pas d'étiquette)
                return CircleLayer(
                  circles: towns
                      .map((p) => CircleMarker(
                            point: p.coords,
                            radius: 4.0,
                            color: const Color(0xFF10B981).withValues(alpha: 0.82),
                            borderStrokeWidth: 1.2,
                            borderColor: Colors.white.withValues(alpha: 0.9),
                          ))
                      .toList(),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Couche 3 : villages + hameaux + localités — point + étiquette à zoom ≥ 9.5 ──
          if (showVillages)
            placesAsync.maybeWhen(
              data: (places) {
                final villages = places.where((p) =>
                    p.type == 'village' || p.type == 'hamlet' ||
                    p.type == 'isolated_dwelling' || p.type == 'locality').toList();
                if (_zoom >= 9.5) {
                  return MarkerLayer(
                    markers: villages
                        .map((p) => Marker(
                              point: p.coords,
                              width: (p.name.length * 4.5 + 10).clamp(40, 95),
                              height: 22,
                              child: _PlaceMarker(
                                  name: p.name,
                                  type: 'village',
                                  onSatellite: tileStyle != _TileStyle.standard),
                            ))
                        .toList(),
                  );
                }
                return CircleLayer(
                  circles: villages
                      .map((p) => CircleMarker(
                            point: p.coords,
                            radius: 3.0,
                            color: (tileStyle == _TileStyle.standard
                                    ? kTextMuted
                                    : Colors.white)
                                .withValues(alpha: 0.65),
                            borderStrokeWidth: 0.8,
                            borderColor: Colors.white.withValues(alpha: 0.55),
                          ))
                      .toList(),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Réseau routier OSM (trunk/primary/secondary/tertiary) ─────────
          // Visible à partir de zoom 6 — coloré par type de voie.
          if (showRoads)
            roadsAsync.maybeWhen(
              data: (roads) {
                if (roads.isEmpty) return const SizedBox.shrink();
                Color roadColor(String type, bool satellite) {
                  final base = switch (type) {
                    'trunk'     => const Color(0xFFF59E0B), // amber
                    'primary'   => const Color(0xFFEF4444), // rouge
                    'secondary' => const Color(0xFF6B7280), // gris
                    _           => const Color(0xFF9CA3AF), // gris clair
                  };
                  return satellite
                      ? base.withValues(alpha: 0.85)
                      : base.withValues(alpha: 0.75);
                }
                double roadWidth(String type) => switch (type) {
                  'trunk'     => 3.0,
                  'primary'   => 2.5,
                  'secondary' => 1.8,
                  _           => 1.2,
                };
                final isSat = tileStyle != _TileStyle.standard;
                return PolylineLayer(
                  polylines: roads.map((r) => Polyline(
                    points: r.points,
                    color: roadColor(r.type, isSat),
                    strokeWidth: roadWidth(r.type),
                  )).toList(),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

          // ── Données scolaires ──────────────────────────────────────────────
          if (showDept)
            MarkerLayer(
              markers: _buildDeptMarkers(widget.data, selected),
            ),
          if (showGps)
            MarkerLayer(
              markers: _buildGpsMarkers(widget.data.gpsSchools, selectedGps),
            ),
          if (showProj)
            projectsAsync.maybeWhen(
              data: (projects) => MarkerLayer(
                markers: _buildProjectMarkers(projects, selectedProj),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

          // Indicateur de chargement des données géo (Overpass peut prendre 15-30 s)
          if (boundaryAsync.isLoading ||
              polygonsAsync.isLoading ||
              placesAsync.isLoading)
            const _GeoLoadingOverlay(),

          RichAttributionWidget(attributions: [
            TextSourceAttribution(
                tileStyle == _TileStyle.standard
                    ? 'OpenStreetMap contributors'
                    : 'Esri, Maxar, OpenStreetMap contributors',
                onTap: null),
          ]),
        ],
      ),
      ),
      Positioned(
        right: 12,
        bottom: 92,
        child: _StreetViewFab(controller: _mapController),
      ),
    ]);
  }
}

// ─── Bandeau de statut des données écoles (non bloquant) ─────────────────────
class _MapDataStatus extends StatelessWidget {
  const _MapDataStatus({required this.loading, required this.error});
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = loading
        ? (Icons.cloud_sync_rounded, 'Chargement des écoles…', kNavy)
        : error != null
            ? (Icons.cloud_off_rounded, 'Écoles indisponibles (réseau)', kRed)
            : (Icons.location_off_rounded, 'Aucune école géolocalisée', kTextMuted);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            const SizedBox(
              width: 13, height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ─── Bouton « Vue rue » (imagerie au niveau du sol via Mapillary) ────────────
// Google Street View ne couvre quasiment pas le Congo ; Mapillary (imagerie
// participative) offre des photos au sol le long des axes des grandes villes.
// Le bouton ouvre le visualiseur centré sur la vue courante de la carte.
class _StreetViewFab extends StatelessWidget {
  const _StreetViewFab({required this.controller});
  final MapController controller;

  void _open(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => MapillaryViewerDialog(center: controller.camera.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.streetview_rounded, size: 16, color: kNavy),
            SizedBox(width: 6),
            Text('Vue rue',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

// ─── Panneau détail département ─────────────────────────────────────────────
class _DeptDetail extends ConsumerWidget {
  const _DeptDetail({required this.dept});
  final AdminDeptEntry dept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate =
        dept.schoolCount > 0 ? dept.activeCount / dept.schoolCount : 0.0;
    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavyDark, kNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(dept.dept,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => ref.read(_selectionProv.notifier).state =
                    const SelectionNone(),
              ),
            ]),
            const Text('Département · République du Congo',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _DetailKpi(value: '${dept.schoolCount}', label: 'Écoles', color: kNavy),
                  const SizedBox(width: 8),
                  _DetailKpi(value: '${dept.activeCount}', label: 'Actives', color: kGreen),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _DetailKpi(value: '${dept.studentCount}', label: 'Élèves', color: _kPurple),
                  const SizedBox(width: 8),
                  _DetailKpi(
                      value: '${(rate * 100).round()}%',
                      label: 'Tx actif',
                      color: rate > 0.6 ? kGreen : kAccent),
                ]),
                const SizedBox(height: 16),
                _TypeMix(schools: dept.schools),
                const SizedBox(height: 14),
                Row(children: [
                  const Text('Établissements',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const Spacer(),
                  Text('${dept.schoolCount}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kNavy)),
                ]),
                const SizedBox(height: 8),
                ...([...dept.schools]
                      ..sort((a, b) => b.students.compareTo(a.students)))
                    .map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: s.isActive ? kGreen : kTextMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: kTextPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        [if (s.city != null) s.city!, _typeLabel(s.type)]
                                            .join(' · '),
                                        style: const TextStyle(
                                            fontSize: 9, color: kTextMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ]),
                            ),
                            const SizedBox(width: 6),
                            Text('${s.students}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy)),
                            const Text(' él.',
                                style: TextStyle(
                                    fontSize: 8.5, color: kTextMuted)),
                          ]),
                        )),
              ]),
        ),
      ]),
    );
  }
}

// ─── Panneau détail école GPS ────────────────────────────────────────────────
class _GpsSchoolDetailPanel extends ConsumerWidget {
  const _GpsSchoolDetailPanel({required this.school});
  final AdminSchoolPin school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColorForPin(school.type);
    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.85), color],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(school.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w800),
                      maxLines: 2),
                  Text(_typeLabel(school.type),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => ref.read(_selectionProv.notifier).state =
                    const SelectionNone(),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _MiniChip(
                  label: school.isActive ? 'Active' : 'Inactive',
                  color: school.isActive ? kGreen : kRed),
              _MiniChip(
                  label: _locationSourceLabel(school.locationSource),
                  color: _locationSourceColor(school.locationSource)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // KPIs
            Row(children: [
              _DetailKpi(
                  value: '${school.students}', label: 'Élèves', color: kNavy),
              const SizedBox(width: 8),
              _DetailKpi(
                  value: school.department ?? '—',
                  label: 'Département', color: _kBlue),
            ]),
            const SizedBox(height: 14),
            // Coordonnées
            const Text('COORDONNÉES GPS',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurface, borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                _CoordRow(label: 'Latitude',
                    value: school.latitude!.toStringAsFixed(6)),
                const SizedBox(height: 4),
                _CoordRow(label: 'Longitude',
                    value: school.longitude!.toStringAsFixed(6)),
                if (school.locationCapturedAt != null) ...[
                  const SizedBox(height: 4),
                  _CoordRow(
                      label: 'Capturé le',
                      value: _fmtDate(school.locationCapturedAt)),
                ],
              ]),
            ),
            if (school.city != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.location_city_rounded,
                    size: 13, color: kTextMuted),
                const SizedBox(width: 6),
                Text(school.city!,
                    style: const TextStyle(
                        fontSize: 12, color: kTextPrimary,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (_) => _SchoolGpsDialog(
                    school: school,
                    onSaved: () {
                      ref.invalidate(adminRegionalProvider);
                      // La sélection contient un instantané (anciennes coords) :
                      // on la vide pour que la carte rafraîchie reflète la
                      // nouvelle position sans afficher un panneau périmé.
                      ref.read(_selectionProv.notifier).state =
                          const SelectionNone();
                    },
                  ),
                ),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                label: const Text('Corriger la position'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: kTextMuted)),
        ),
        Expanded(
          child: SelectableText(value,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  fontFamily: 'monospace')),
        ),
        GestureDetector(
          onTap: () =>
              Clipboard.setData(ClipboardData(text: value)),
          child: const Icon(Icons.copy_rounded, size: 12, color: kTextMuted),
        ),
      ]);
}

// ─── Panneau détail projet ───────────────────────────────────────────────────
class _ProjectDetailPanel extends ConsumerWidget {
  const _ProjectDetailPanel({
    required this.project,
    required this.onEdit,
    required this.onDelete,
  });
  final AdminProjectPin project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _projectStatusColor(project.status);
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor.withValues(alpha: 0.85), statusColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_projectStatusIcon(project.status),
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(project.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w800),
                      maxLines: 2),
                  Text(_projectStatusLabel(project.status),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ]),
              ),
              Row(children: [
                _IconBtn(icon: Icons.edit_rounded, onTap: onEdit),
                _IconBtn(icon: Icons.delete_rounded, onTap: onDelete),
                _IconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => ref.read(_selectionProv.notifier).state =
                        const SelectionNone()),
              ]),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _MiniChip(
                  label: _priorityLabel(project.priority),
                  color: _priorityColor(project.priority)),
              if (project.schoolType != null)
                _MiniChip(
                    label: _typeLabel(project.schoolType!),
                    color: _typeColorForPin(project.schoolType!)),
              if (project.beneficiariesEst != null)
                _MiniChip(
                    label: '${project.beneficiariesEst} bénéf.',
                    color: Colors.white.withValues(alpha: 0.3)),
            ]),
          ]),
        ),
        // Pipeline de statut
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _StatusPipeline(currentStatus: project.status),
        ),
        // Détails
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const Text('DESCRIPTION',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Text(project.description!,
                      style: const TextStyle(
                          fontSize: 11.5, color: kTextPrimary, height: 1.4)),
                  const SizedBox(height: 14),
                ],
                // Localisation
                Row(children: [
                  _DetailKpi(
                      value:
                          '${project.latitude.toStringAsFixed(4)}, ${project.longitude.toStringAsFixed(4)}',
                      label: 'Coords',
                      color: _kBlue),
                ]),
                if (project.department != null || project.city != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.place_rounded, size: 13, color: kTextMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          [project.city, project.department]
                              .whereType<String>()
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: kTextPrimary)),
                    ),
                  ]),
                ],
                if (project.budgetXaf != null) ...[
                  const SizedBox(height: 14),
                  const Text('BUDGET',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_rounded,
                          size: 14, color: kAccent),
                      const SizedBox(width: 8),
                      Text('${fmt.format(project.budgetXaf)} FCFA',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                    ]),
                  ),
                ],
                if (project.comments != null &&
                    project.comments!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('COMMENTAIRES',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kTextMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(project.comments!,
                        style: const TextStyle(
                            fontSize: 11, color: kTextPrimary, height: 1.4)),
                  ),
                ],
                if (project.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text('Créé le ${_fmtDate(project.createdAt)}',
                      style: const TextStyle(
                          fontSize: 9, color: kTextMuted)),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white70, size: 15),
        ),
      );
}

// ─── Pipeline de statut projet ───────────────────────────────────────────────
class _StatusPipeline extends StatelessWidget {
  const _StatusPipeline({required this.currentStatus});
  final String currentStatus;

  static const _steps = [
    ('etude', 'Étude'),
    ('validation', 'Validation'),
    ('budgetisation', 'Budget.'),
    ('construction', 'Constr.'),
    ('acheve', 'Achevé'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexWhere((s) => s.$1 == currentStatus);
    return Row(
      children: _steps.asMap().entries.map((e) {
        final i    = e.key;
        final step = e.value;
        final isDone    = i < currentIdx;
        final isCurrent = i == currentIdx;
        final dotColor  = isCurrent
            ? _projectStatusColor(currentStatus)
            : isDone
                ? kGreen
                : kBorder;
        return Expanded(
          child: Column(children: [
            Row(children: [
              if (i > 0)
                Expanded(
                    child: Container(
                        height: 2,
                        color: isDone || isCurrent ? kGreen : kBorder)),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? dotColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: isDone || isCurrent
                    ? Icon(
                        isDone
                            ? Icons.check_rounded
                            : _projectStatusIcon(currentStatus),
                        size: 8,
                        color: Colors.white)
                    : null,
              ),
              if (i < _steps.length - 1)
                Expanded(
                    child: Container(
                        height: 2,
                        color: i < currentIdx ? kGreen : kBorder)),
            ]),
            const SizedBox(height: 4),
            Text(step.$2,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? dotColor : kTextMuted),
                textAlign: TextAlign.center),
          ]),
        );
      }).toList(),
    );
  }
}

// ─── Analyse régionale ───────────────────────────────────────────────────────
class _RegionalAnalytics extends ConsumerWidget {
  const _RegionalAnalytics({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(adminProjectsProvider);
    final maxSchools    = data.depts.isEmpty
        ? 1
        : data.depts.fold(0, (m, d) => d.schoolCount > m ? d.schoolCount : m);
    final avgStudents   = data.totalSchools > 0
        ? (data.totalStudents / data.totalSchools).toStringAsFixed(1)
        : '0';
    final gpsPct = data.totalSchools > 0
        ? (data.gpsCount * 100 / data.totalSchools).round()
        : 0;

    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavyDark, kNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Analyse régionale',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 4),
                Text('Répartition des établissements',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
              ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPS coverage
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.gps_fixed_rounded,
                        size: 16, color: kGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$gpsPct% géolocalisées',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary)),
                            Text('${data.gpsCount} / ${data.totalSchools} écoles avec GPS',
                                style: const TextStyle(
                                    fontSize: 9, color: kTextMuted)),
                          ]),
                    ),
                    if (data.noGpsCount > 0)
                      Text('${data.noGpsCount} sans',
                          style: const TextStyle(
                              fontSize: 10, color: kRed,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 12),
                // Projets summary
                projectsAsync.maybeWhen(
                  data: (projects) {
                    if (projects.isEmpty) return const SizedBox.shrink();
                    final inProgress = projects
                        .where((p) => p.status != 'acheve')
                        .length;
                    final done = projects
                        .where((p) => p.status == 'acheve')
                        .length;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kOrange.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business_center_rounded,
                            size: 16, color: _kOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${projects.length} projet${projects.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary)),
                                Text('$inProgress en cours · $done achevé${done > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 9, color: kTextMuted)),
                              ]),
                        ),
                      ]),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                _TerritorialAnalysis(data: data),
                const SizedBox(height: 14),
                const Text('INDICATEURS CLÉS',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: kTextMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(children: [
                  _AnalyticKpi(
                      label: 'Élèves/École',
                      value: avgStudents, color: kNavy),
                  const SizedBox(width: 8),
                  _AnalyticKpi(
                      label: 'Départements',
                      value: '${data.coveredDepts}', color: kAccent),
                ]),
                const SizedBox(height: 16),
                _TypeMix(
                    schools: [
                  for (final d in data.depts) ...d.schools,
                  ...data.gpsSchools,
                ]),
                const SizedBox(height: 16),
                const Divider(color: kBorder),
                const SizedBox(height: 12),
                const Text('CLASSEMENT PAR ÉCOLES',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: kTextMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                ...data.depts.take(8).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value;
                  final ratio =
                      maxSchools > 0 ? d.schoolCount / maxSchools : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: (i < 3 ? kAccent : kSurface)
                                    .withValues(alpha: i < 3 ? 0.2 : 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: i < 3
                                              ? const Color(0xFFB45309)
                                              : kTextMuted))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(d.dept,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text('${d.schoolCount}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const SizedBox(width: 28),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: kSurface,
                                  valueColor: AlwaysStoppedAnimation(
                                      d.activeCount == 0 ? kRed : kGreen),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${d.studentCount} él.',
                                style: const TextStyle(
                                    fontSize: 9, color: kTextMuted)),
                          ]),
                        ]),
                  );
                }),
                const SizedBox(height: 16),
                const Divider(color: kBorder),
                const SizedBox(height: 12),
                const _DataGaps(),
              ]),
        ),
      ]),
    );
  }
}

// ─── Analyse territoriale (distances réelles) ────────────────────────────────
class _TerritorialAnalysis extends ConsumerWidget {
  const _TerritorialAnalysis({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Villes & bourgs réels (OSM) comme agglomérations de référence.
    final agglos = ref.watch(congoPlacesProvider).maybeWhen(
          data: (places) => places
              .where((p) => p.type == 'city' || p.type == 'town')
              .toList(),
          orElse: () => const <GeoPlace>[],
        );
    final report = _buildTerritorialReport(data, agglos);

    Widget header() => Row(children: [
          const Icon(Icons.straighten_rounded, size: 13, color: _kPurple),
          const SizedBox(width: 6),
          const Text('ANALYSE TERRITORIALE',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: kTextMuted,
                  letterSpacing: 1.0)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Haversine réel',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: _kPurple)),
          ),
        ]);

    if (!report.hasAny) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withValues(alpha: 0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.location_off_rounded, size: 18, color: kAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucune école géolocalisée (GPS). Les distances ne sont '
                'calculées que sur des coordonnées réelles — aucune donnée '
                'inventée. Capturez le GPS depuis le détail d\'une école pour '
                'activer l\'analyse de distance.',
                style: TextStyle(
                    fontSize: 10, color: kTextPrimary, height: 1.4),
              ),
            ),
          ]),
        ),
      ]);
    }

    final top = report.stats.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header(),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _TerritorialKpi(
            icon: Icons.school_rounded,
            label: 'Dist. école voisine',
            value: _fmtKm(report.avgNearestKm),
            hint: report.hasPairwise ? 'moyenne' : 'min. 2 écoles GPS',
            color: _kPurple,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TerritorialKpi(
            icon: Icons.location_city_rounded,
            label: 'Dist. agglo. princ.',
            value: _fmtKm(report.avgCityKm),
            hint: 'ville/bourg réel le + proche',
            color: _kBlue,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      const Text('ÉCOLES LES PLUS ISOLÉES',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
              letterSpacing: 1.0)),
      const SizedBox(height: 8),
      ...top.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 14, color: _kPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.school.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(
                          s.nearestSchoolKm != null
                              ? 'École voisine : ${_fmtKm(s.nearestSchoolKm)} · ${s.nearestCity} ${_fmtKm(s.nearestCityKm)}'
                              : '${s.nearestCity} ${_fmtKm(s.nearestCityKm)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9, color: kTextMuted)),
                    ]),
              ),
            ]),
          )),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${report.gpsSchools}/${report.totalSchools} écoles avec GPS réel. '
              'Les autres sont positionnées au chef-lieu départemental '
              '(approximation, exclues du calcul de distance).',
              style: const TextStyle(
                  fontSize: 9, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _TerritorialKpi extends StatelessWidget {
  const _TerritorialKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        Text(hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, color: kTextMuted)),
      ]),
    );
  }
}

// ─── Couches cartographiques : disponibles vs manquantes ─────────────────────
class _DataGaps extends StatelessWidget {
  const _DataGaps();

  // (titre, description, source, icône, disponible)
  static const _items = [
    (
      'Villages & localités',
      'Localités OSM mappées (villes · bourgs · villages · hameaux) — '
          'couche activable via le toggle "Villages". Données incomplètes '
          'dans les zones reculées : contribuer sur openstreetmap.org.',
      'OpenStreetMap (live Overpass + asset embarqué)',
      Icons.holiday_village_rounded,
      true,
    ),
    (
      'Réseau routier',
      'Routes nationales, régionales et locales (trunk/primary/secondary/'
          'tertiary). Activer le toggle "Routes" dans les couches.',
      'OpenStreetMap via Overpass API',
      Icons.route_rounded,
      true,
    ),
    (
      'Densité de population',
      'Détection automatique des zones sous-équipées & besoins en écoles.',
      'INS Congo — RGPH (recensement)',
      Icons.groups_rounded,
      false,
    ),
    (
      'Isochrones / temps de trajet',
      'Accessibilité réelle par route (10 min, 30 min, 1 h). Nécessite un '
          'serveur de routage OSRM dédié.',
      'Moteur OSRM + données OSM Congo',
      Icons.timer_rounded,
      false,
    ),
    (
      'Projections démographiques',
      'Prévisions 5 et 10 ans par département.',
      'INS Congo — projections officielles',
      Icons.trending_up_rounded,
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final available = _items.where((i) => i.$5).toList();
    final missing   = _items.where((i) => !i.$5).toList();

    Widget tile(
      String title,
      String desc,
      String source,
      IconData icon,
      bool ok,
    ) {
      final color = ok ? kGreen : kRed;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ok ? kGreen.withValues(alpha: 0.35) : kBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ok ? 'Disponible' : 'Manquante',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 9, color: kTextMuted, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      ok ? Icons.check_circle_outline_rounded
                         : Icons.verified_outlined,
                      size: 11,
                      color: ok ? kGreen : const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Source : $source',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: ok ? kGreen : const Color(0xFF0EA5E9))),
                    ),
                  ]),
                ]),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Couches disponibles ──────────────────────────────────────────────────
      const Row(children: [
        Icon(Icons.layers_rounded, size: 13, color: kGreen),
        SizedBox(width: 6),
        Text('COUCHES DISPONIBLES',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 1.0)),
      ]),
      const SizedBox(height: 6),
      ...available.map((i) => tile(i.$1, i.$2, i.$3, i.$4, i.$5)),

      const SizedBox(height: 10),
      const Divider(color: kBorder),
      const SizedBox(height: 10),

      // ── Couches manquantes ───────────────────────────────────────────────────
      const Row(children: [
        Icon(Icons.layers_clear_rounded, size: 13, color: kRed),
        SizedBox(width: 6),
        Text('COUCHES MANQUANTES',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 1.0)),
      ]),
      const SizedBox(height: 4),
      const Text(
        'Données d\'institutions nationales — non présentes en base. '
        'Aucune n\'est simulée (« ne rien inventer »).',
        style: TextStyle(fontSize: 9, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 8),
      ...missing.map((i) => tile(i.$1, i.$2, i.$3, i.$4, i.$5)),
    ]);
  }
}

// ─── Dialogue création / modification projet ─────────────────────────────────
class _ProjectFormDialog extends ConsumerStatefulWidget {
  const _ProjectFormDialog({
    required this.initialCoords,
    this.project,
    required this.onSaved,
  });
  final LatLng initialCoords;
  final AdminProjectPin? project;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _benCtrl;
  late final TextEditingController _commentsCtrl;
  String _status   = 'etude';
  String _priority = 'moyenne';
  String? _schoolType;
  String? _department;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl     = TextEditingController(text: p?.name ?? '');
    _descCtrl     = TextEditingController(text: p?.description ?? '');
    _cityCtrl     = TextEditingController(text: p?.city ?? '');
    _budgetCtrl   = TextEditingController(
        text: p?.budgetXaf?.toString() ?? '');
    _benCtrl      = TextEditingController(
        text: p?.beneficiariesEst?.toString() ?? '');
    _commentsCtrl = TextEditingController(text: p?.comments ?? '');
    _status       = p?.status ?? 'etude';
    _priority     = p?.priority ?? 'moyenne';
    _schoolType   = p?.schoolType;
    _department   = p?.department;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _budgetCtrl.dispose();
    _benCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(adminProjectServiceProvider);
      if (widget.project == null) {
        await svc.createProject(
          name:             _nameCtrl.text.trim(),
          latitude:         widget.initialCoords.latitude,
          longitude:        widget.initialCoords.longitude,
          status:           _status,
          description:      _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim() : null,
          schoolType:       _schoolType,
          department:       _department,
          city:             _cityCtrl.text.trim().isNotEmpty
              ? _cityCtrl.text.trim() : null,
          budgetXaf:        int.tryParse(_budgetCtrl.text.trim()),
          beneficiariesEst: int.tryParse(_benCtrl.text.trim()),
          priority:         _priority,
          comments:         _commentsCtrl.text.trim().isNotEmpty
              ? _commentsCtrl.text.trim() : null,
        );
      } else {
        await svc.updateProject(
          id:               widget.project!.id,
          name:             _nameCtrl.text.trim(),
          status:           _status,
          description:      _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim() : null,
          schoolType:       _schoolType,
          department:       _department,
          city:             _cityCtrl.text.trim().isNotEmpty
              ? _cityCtrl.text.trim() : null,
          budgetXaf:        int.tryParse(_budgetCtrl.text.trim()),
          beneficiariesEst: int.tryParse(_benCtrl.text.trim()),
          priority:         _priority,
          comments:         _commentsCtrl.text.trim().isNotEmpty
              ? _commentsCtrl.text.trim() : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 660),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFF5500), _kOrange],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.add_location_alt_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        isEdit ? 'Modifier le projet' : 'Nouveau projet scolaire',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            // Coords badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: kSurface,
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 13, color: _kOrange),
                const SizedBox(width: 6),
                Text(
                    '${widget.initialCoords.latitude.toStringAsFixed(5)}, '
                    '${widget.initialCoords.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontSize: 11, color: kTextMuted,
                        fontFamily: 'monospace')),
              ]),
            ),
            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(children: [
                  // Nom
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: adminInputDecoration('Nom du projet *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Champ obligatoire' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    decoration: adminInputDecoration('Description (optionnel)'),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  // Statut + Priorité
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: adminInputDecoration('Statut'),
                        items: const [
                          DropdownMenuItem(
                              value: 'etude', child: Text('Étude')),
                          DropdownMenuItem(
                              value: 'validation', child: Text('Validation')),
                          DropdownMenuItem(
                              value: 'budgetisation',
                              child: Text('Budgétisation')),
                          DropdownMenuItem(
                              value: 'construction',
                              child: Text('Construction')),
                          DropdownMenuItem(
                              value: 'acheve', child: Text('Achevé')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'etude'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: adminInputDecoration('Priorité'),
                        items: const [
                          DropdownMenuItem(
                              value: 'haute', child: Text('Haute')),
                          DropdownMenuItem(
                              value: 'moyenne', child: Text('Moyenne')),
                          DropdownMenuItem(
                              value: 'basse', child: Text('Basse')),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'moyenne'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Type + Département
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _schoolType,
                        decoration: adminInputDecoration('Type'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('— Non précisé')),
                          DropdownMenuItem(
                              value: 'public', child: Text('Public')),
                          DropdownMenuItem(
                              value: 'prive', child: Text('Privé')),
                          DropdownMenuItem(
                              value: 'mixte', child: Text('Mixte')),
                        ],
                        onChanged: (v) => setState(() => _schoolType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _department,
                        decoration: adminInputDecoration('Département'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Non précisé')),
                          ...const [
                            'Bouenza', 'Brazzaville', 'Congo-Oubangui',
                            'Cuvette', 'Cuvette-Ouest', 'Djoué-Léfini',
                            'Kouilou', 'Lékoumou', 'Likouala', 'Niari',
                            'Nkéni-Alima', 'Plateaux', 'Pointe-Noire',
                            'Pool', 'Sangha',
                          ].map((d) => DropdownMenuItem(
                                value: d, child: Text(d))),
                        ],
                        onChanged: (v) => setState(() => _department = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Ville
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: adminInputDecoration('Ville / Localité'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  // Budget + Bénéficiaires
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _budgetCtrl,
                        decoration:
                            adminInputDecoration('Budget (FCFA)'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _benCtrl,
                        decoration: adminInputDecoration(
                            'Bénéficiaires estimés'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Commentaires
                  TextFormField(
                    controller: _commentsCtrl,
                    decoration: adminInputDecoration('Commentaires'),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(isEdit ? 'Enregistrer' : 'Créer le projet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Dialogue : corriger la position GPS d'une école ─────────────────────────
class _SchoolGpsDialog extends ConsumerStatefulWidget {
  const _SchoolGpsDialog({required this.school, required this.onSaved});
  final AdminSchoolPin school;
  final VoidCallback onSaved;

  @override
  ConsumerState<_SchoolGpsDialog> createState() => _SchoolGpsDialogState();
}

class _SchoolGpsDialogState extends ConsumerState<_SchoolGpsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _saving = false;

  // Bornes de la République du Congo (avec marge). Un point hors de ces bornes
  // est presque sûrement une erreur de saisie (lat/lng inversées, signe oublié).
  static const _latMin = -5.2, _latMax = 3.8, _lngMin = 11.0, _lngMax = 18.8;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(
        text: widget.school.latitude?.toStringAsFixed(6) ?? '');
    _lngCtrl = TextEditingController(
        text: widget.school.longitude?.toStringAsFixed(6) ?? '');
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? _parse(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  String? _validateLat(String? v) {
    final d = _parse(v);
    if (d == null) return 'Latitude invalide';
    if (d < _latMin || d > _latMax) return 'Hors Congo ($_latMin à $_latMax)';
    return null;
  }

  String? _validateLng(String? v) {
    final d = _parse(v);
    if (d == null) return 'Longitude invalide';
    if (d < _lngMin || d > _lngMax) return 'Hors Congo ($_lngMin à $_lngMax)';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminProjectServiceProvider).patchSchoolGps(
            schoolId: widget.school.id,
            latitude: _parse(_latCtrl.text)!,
            longitude: _parse(_lngCtrl.text)!,
            source: 'manual',
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Position mise à jour'), backgroundColor: kGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [kNavy, _kBlue],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_location_alt_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Corriger la position GPS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.school.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: adminInputDecoration('Latitude *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]')),
                      ],
                      validator: _validateLat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: adminInputDecoration('Longitude *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]')),
                      ],
                      validator: _validateLng,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: kTextMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'La position sera marquée « saisie manuelle ». '
                        'Bornes Congo : lat $_latMin…$_latMax, '
                        'lng $_lngMin…$_lngMax.',
                        style: TextStyle(
                            fontSize: 10, color: kTextMuted, height: 1.3)),
                  ),
                ]),
              ]),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires locaux ──────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
}

class _DetailKpi extends StatelessWidget {
  const _DetailKpi(
      {required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(fontSize: 9, color: kTextMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _TypeMix extends StatelessWidget {
  const _TypeMix({required this.schools});
  final List<AdminSchoolPin> schools;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final s in schools) {
      counts[s.type] = (counts[s.type] ?? 0) + 1;
    }
    const order = ['public', 'prive', 'mixte'];
    final present = [
      ...order.where((t) => (counts[t] ?? 0) > 0),
      ...counts.keys.where((k) => !order.contains(k)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("TYPES D'ÉTABLISSEMENT",
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: kTextMuted, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(children: [
          for (final t in present)
            Expanded(
              flex: counts[t]!,
              child: Container(height: 8, color: _typeColor(t)),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (final t in present)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: _typeColor(t), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${_typeLabel(t)} · ${counts[t]}',
                style: const TextStyle(
                    fontSize: 10, color: kTextPrimary)),
          ]),
      ]),
    ]);
  }
}

class _AnalyticKpi extends StatelessWidget {
  const _AnalyticKpi(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: kTextMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ─── Fonctions utilitaires ───────────────────────────────────────────────────
String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive'  => 'Privé',
      'mixte'  => 'Mixte',
      _        => t,
    };

Color _typeColor(String t) => switch (t) {
      'public' => _kBlue,
      'prive'  => kGreen,
      'mixte'  => _kPurple,
      _        => kTextMuted,
    };

Color _typeColorForPin(String t) => switch (t) {
      'public' => _kBlue,
      'prive'  => kGreen,
      'mixte'  => _kPurple,
      _        => kNavy,
    };

String _projectStatusLabel(String s) => switch (s) {
      'etude'         => 'Étude',
      'validation'    => 'Validation',
      'budgetisation' => 'Budgétisation',
      'construction'  => 'Construction',
      'acheve'        => 'Achevé',
      _               => s,
    };

Color _projectStatusColor(String s) => switch (s) {
      'etude'         => kTextMuted,
      'validation'    => kAccent,
      'budgetisation' => _kOrange,
      'construction'  => _kBlue,
      'acheve'        => kGreen,
      _               => kTextMuted,
    };

IconData _projectStatusIcon(String s) => switch (s) {
      'etude'         => Icons.search_rounded,
      'validation'    => Icons.fact_check_rounded,
      'budgetisation' => Icons.account_balance_rounded,
      'construction'  => Icons.construction_rounded,
      'acheve'        => Icons.check_circle_rounded,
      _               => Icons.circle_outlined,
    };

String _locationSourceLabel(String? s) => switch (s) {
      'gps'      => 'GPS terrain',
      'geocoded' => 'Géocodé',
      'manual'   => 'Manuel',
      _          => 'Source inconnue',
    };

Color _locationSourceColor(String? s) => switch (s) {
      'gps'      => kGreen,
      'geocoded' => kAccent,
      'manual'   => _kBlue,
      _          => kTextMuted,
    };

String _priorityLabel(String p) => switch (p) {
      'haute'   => 'Priorité haute',
      'moyenne' => 'Priorité moyenne',
      'basse'   => 'Priorité basse',
      _         => p,
    };

Color _priorityColor(String p) => switch (p) {
      'haute'   => kRed,
      'moyenne' => _kOrange,
      'basse'   => kGreen,
      _         => kTextMuted,
    };

String _fmtDate(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}';
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.',
  'mai', 'juin', 'juil.', 'août',
  'sept.', 'oct.', 'nov.', 'déc.',
];

String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// Diamètre bulle départementale proportionnel à l'effectif (échelle √).
double _bubbleDiameter(int students, int maxStudents) {
  if (maxStudents <= 0) return 30;
  final r = (students / maxStudents).clamp(0.0, 1.0);
  return 30 + 30 * math.sqrt(r);
}

// ─── Analyse territoriale — distances réelles (Haversine via latlong2) ────────
// AUCUNE donnée inventée : ne calcule que sur des coordonnées GPS réelles
// (écoles géolocalisées) et les villes/bourgs réels OpenStreetMap.
const Distance _kGeo = Distance();

class _IsolationStat {
  const _IsolationStat({
    required this.school,
    required this.nearestSchool,
    required this.nearestSchoolKm,
    required this.nearestCity,
    required this.nearestCityKm,
  });
  final AdminSchoolPin school;
  final AdminSchoolPin? nearestSchool;
  final double? nearestSchoolKm; // null si < 2 écoles géolocalisées
  final String nearestCity;
  final double nearestCityKm;
}

class _TerritorialReport {
  const _TerritorialReport({
    required this.gpsSchools,
    required this.totalSchools,
    required this.stats,
    required this.avgNearestKm,
    required this.avgCityKm,
  });
  final int gpsSchools;
  final int totalSchools;
  final List<_IsolationStat> stats; // trié : plus isolé d'abord
  final double? avgNearestKm;
  final double? avgCityKm;

  bool get hasAny => gpsSchools >= 1;
  bool get hasPairwise => gpsSchools >= 2;
}

_TerritorialReport _buildTerritorialReport(
  AdminRegionalData data,
  List<GeoPlace> agglomerations,
) {
  final gps = data.gpsSchools.where((s) => s.hasGps).toList();
  final stats = <_IsolationStat>[];
  double sumNearest = 0;
  int countNearest = 0;
  double sumCity = 0;
  int countCity = 0;

  // Agglomérations de référence : villes & bourgs réels (OpenStreetMap).
  // Repli sur les chefs-lieux départementaux tant que la couche localités
  // n'est pas chargée — aucune coordonnée inventée dans les deux cas.
  final aggloList = agglomerations.isNotEmpty
      ? [for (final p in agglomerations) (p.name, p.coords)]
      : [for (final e in adminMajorAgglomerations.entries) (e.key, e.value)];

  for (final s in gps) {
    final sc = s.gpsCoords!;

    AdminSchoolPin? near;
    double? nearKm;
    for (final o in gps) {
      if (identical(o, s)) continue;
      final km = _kGeo.as(LengthUnit.Kilometer, sc, o.gpsCoords!);
      if (nearKm == null || km < nearKm) {
        nearKm = km;
        near = o;
      }
    }
    if (nearKm != null) {
      sumNearest += nearKm;
      countNearest++;
    }

    String city = '—';
    double cityKm = double.infinity;
    for (final (name, coord) in aggloList) {
      final km = _kGeo.as(LengthUnit.Kilometer, sc, coord);
      if (km < cityKm) {
        cityKm = km;
        city = name;
      }
    }
    if (cityKm.isFinite) {
      sumCity += cityKm;
      countCity++;
    }

    stats.add(_IsolationStat(
      school: s,
      nearestSchool: near,
      nearestSchoolKm: nearKm,
      nearestCity: city,
      nearestCityKm: cityKm.isFinite ? cityKm : 0,
    ));
  }

  stats.sort((a, b) {
    final ax = a.nearestSchoolKm ?? a.nearestCityKm;
    final bx = b.nearestSchoolKm ?? b.nearestCityKm;
    return bx.compareTo(ax);
  });

  return _TerritorialReport(
    gpsSchools: gps.length,
    totalSchools: data.totalSchools,
    stats: stats,
    avgNearestKm: countNearest > 0 ? sumNearest / countNearest : null,
    avgCityKm: countCity > 0 ? sumCity / countCity : null,
  );
}

String _fmtKm(double? km) {
  if (km == null) return '—';
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
