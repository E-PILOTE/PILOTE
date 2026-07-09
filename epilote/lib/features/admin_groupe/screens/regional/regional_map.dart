part of '../admin_regional_view.dart';

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

  // Rebuild aux seuils de lisibilité (villes/bourgs/villages) ET à chaque
  // demi-niveau de zoom pour que le clustering des écoles s'affine progressivement.
  void _onZoom(MapCamera camera, bool _) {
    final z = camera.zoom;
    final cross = (_zoom < 7.0) != (z < 7.0) ||
        (_zoom < 9.5) != (z < 9.5) ||
        (_zoom * 2).floor() != (z * 2).floor();
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

  // Couleur d'un pin selon le mode actif (type, charge pédagogique, occupation).
  Color _pinColor(AdminSchoolPin s, _PinColorMode mode, Map<String, int> load,
      Map<String, int> occ) {
    if (!s.isActive) return kRed;
    if (mode == _PinColorMode.load) {
      return loadColor(load[s.id] ?? 0);
    }
    if (mode == _PinColorMode.occupancy) {
      return occColor(occ[s.id] ?? 0);
    }
    return _typeColorForPin(s.type);
  }

  List<Marker> _buildGpsMarkers(
    List<AdminSchoolPin> schools,
    AdminSchoolPin? selectedGps,
    _PinColorMode colorMode,
    Map<String, int> loadById,
    Map<String, int> occById,
  ) {
    // ── Clustering léger maison ────────────────────────────────────────────
    // À l'échelle nationale (zoom faible), des centaines d'écoles se
    // superposent → on regroupe par cellule de grille dont la taille diminue
    // avec le zoom. Au-delà de z≈9.5 (vue locale) on affiche chaque école.
    // La grappe sélectionnée reste toujours éclatée pour montrer l'école.
    const clusterUntilZoom = 9.5;
    final markers = <Marker>[];

    if (_zoom < clusterUntilZoom) {
      final cell =
          1.6 / math.pow(2, (_zoom - 6).clamp(0, 6)); // degrés
      final groups = <String, List<AdminSchoolPin>>{};
      for (final s in schools) {
        final c = s.gpsCoords!;
        final key =
            '${(c.latitude / cell).floor()}|${(c.longitude / cell).floor()}';
        groups.putIfAbsent(key, () => []).add(s);
      }
      for (final group in groups.values) {
        final hasSelected =
            selectedGps != null && group.any((s) => s.id == selectedGps.id);
        if (group.length == 1 || hasSelected) {
          for (final s in group) {
            markers.add(_singleGpsMarker(
                s, selectedGps, colorMode, loadById, occById));
          }
        } else {
          markers.add(
              _clusterMarker(group, colorMode, loadById, occById, cell));
        }
      }
      return markers;
    }

    for (final s in schools) {
      markers.add(
          _singleGpsMarker(s, selectedGps, colorMode, loadById, occById));
    }
    return markers;
  }

  Marker _clusterMarker(List<AdminSchoolPin> group, _PinColorMode colorMode,
      Map<String, int> loadById, Map<String, int> occById, double cell) {
    // Centre = barycentre du groupe.
    var lat = 0.0, lng = 0.0, students = 0;
    var inactive = 0;
    for (final s in group) {
      final c = s.gpsCoords!;
      lat += c.latitude;
      lng += c.longitude;
      students += s.students;
      if (!s.isActive) inactive += 1;
    }
    final center = LatLng(lat / group.length, lng / group.length);
    final dia = (34.0 + group.length.clamp(0, 40) * 0.8).toDouble();
    // Teinte : rouge si tout inactif, sinon navy ; pastille charge en mode load.
    final allInactive = inactive == group.length;
    final base = allInactive
        ? kRed
        : switch (colorMode) {
            _PinColorMode.load => _clusterWorstColor(group, loadById, loadColor),
            _PinColorMode.occupancy =>
              _clusterWorstColor(group, occById, occColor),
            _PinColorMode.type => kNavy,
          };
    return Marker(
      point: center,
      width: dia + 10,
      height: dia + 24,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _mapController.move(
            center, (_zoom + 2.2).clamp(6.0, 13.0)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: dia, height: dia,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: base.withValues(alpha: 0.45),
                    blurRadius: 9, offset: const Offset(0, 3)),
              ],
            ),
            child: Text('${group.length}',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: dia < 40 ? 13 : 15,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBorder),
            ),
            child: Text('$students él.',
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
        ]),
      ),
    );
  }

  // Couleur dominante d'une grappe (pire niveau connu) selon une échelle donnée.
  Color _clusterWorstColor(List<AdminSchoolPin> group,
      Map<String, int> levelById, Color Function(int) scale) {
    var worst = 0;
    for (final s in group) {
      final l = levelById[s.id] ?? 0;
      if (l > worst) worst = l;
    }
    return worst == 0 ? kNavy : scale(worst);
  }

  Marker _singleGpsMarker(AdminSchoolPin school, AdminSchoolPin? selectedGps,
      _PinColorMode colorMode, Map<String, int> loadById,
      Map<String, int> occById) {
    final isSelected = selectedGps?.id == school.id;
    final color = _pinColor(school, colorMode, loadById, occById);
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
              color: color.withValues(alpha: 0.9),
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
    final pinColorMode     = ref.watch(_pinColorModeProv);
    // Charge pédagogique (élèves/classe) et occupation (effectif/capacité) par
    // école, depuis le provider tableau — servent à colorer pins et grappes.
    final loadById = <String, int>{};
    final occById  = <String, int>{};
    for (final r in (ref.watch(regionalTableRowsProvider).valueOrNull ??
        const <RegionalTableRow>[])) {
      loadById[r.school.id] = r.loadLevel;
      occById[r.school.id]  = r.occupancyLevel;
    }
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
              markers: _buildGpsMarkers(widget.data.gpsSchools, selectedGps,
                  pinColorMode, loadById, occById),
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

