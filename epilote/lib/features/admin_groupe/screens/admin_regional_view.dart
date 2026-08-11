import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/wayback_provider.dart';

import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/admin_geo_provider.dart';
import '../providers/admin_regional_provider.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/regional_table_provider.dart';
import '../../examens/models/exam_stats.dart' show ExamStatLine;
import '../services/regional_pdf_service.dart';
import '../../../core/widgets/admin_ui.dart';
import '../widgets/esri_tile_provider.dart';
import '../widgets/mapillary_viewer.dart';
import '../widgets/school_satellite_view.dart';
import 'admin_schools_screen.dart' show openSchoolDetailDialog;
import 'regional_table_mode.dart';
import '../../../core/utils/message_erreur.dart';

part 'regional/regional_state.dart';
part 'regional/regional_bars.dart';
part 'regional/regional_toggles.dart';
part 'regional/regional_markers.dart';
part 'regional/regional_map.dart';
part 'regional/regional_map_controls.dart';
part 'regional/regional_pipeline.dart';
part 'regional/regional_panels.dart';
part 'regional/regional_school_panel.dart';
part 'regional/regional_project_panel.dart';
part 'regional/regional_analytics.dart';
part 'regional/regional_territorial.dart';
part 'regional/regional_project_dialog.dart';
part 'regional/regional_gps_dialog.dart';
part 'regional/regional_widgets.dart';


const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kOrange = Color(0xFFFF6B35);

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
    final mode  = ref.watch(_regionalModeProv);
    return Column(
      children: [
        const _ModeSwitch(),
        const SizedBox(height: 12),
        Expanded(
          child: mode == RegionalViewMode.map
              ? _MapLayout(
                  data: async.valueOrNull ?? AdminRegionalData.empty,
                  dataLoading: async.isLoading,
                  dataError: async.hasError ? '${async.error}' : null,
                )
              : const RegionalTableMode(),
        ),
      ],
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
    final streetViewCenter = ref.watch(_streetViewCenterProv);

    // Dialog de création projet déclenché par le tap sur la carte
    ref.listen<LatLng?>(_pendingProjectCoordsProv, (_, coords) {
      if (coords == null) return;
      ref.read(_pendingProjectCoordsProv.notifier).state = null;
      // Pré-remplit le département depuis le point tapé (centroïde le plus proche).
      final depts = ref.read(congoDepartmentsProvider).valueOrNull ??
          const <GeoDepartment>[];
      final suggested = _nearestDeptName(depts, coords);
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => _ProjectFormDialog(
          initialCoords: coords,
          suggestedDepartment: suggested,
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
                              Divider(height: 1, color: kBorder),
                              const _PipelinePanel(),
                              Divider(height: 1, color: kBorder),
                              _CoveragePanel(data: view),
                              Divider(height: 1, color: kBorder),
                              const _FilterBar(),
                              Divider(height: 1, color: kBorder),
                              const _LayerToggleBar(),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: kBorder),
                        _RegionalExportBar(data: data),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: kBorder),
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
                    // Vue rue immersive : couvre toute la zone carte (chrome
                    // inclus) → présentation intégrée, pas un popup.
                    if (streetViewCenter != null)
                      Positioned.fill(
                        child: MapillaryPanel(
                          center: streetViewCenter,
                          onClose: () => ref
                              .read(_streetViewCenterProv.notifier)
                              .state = null,
                        ),
                      ),
                  ],
                ),
              ),
              if (showRight) ...[
                VerticalDivider(width: 1, color: kBorder),
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

