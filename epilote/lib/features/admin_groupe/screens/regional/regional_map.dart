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
  // Délimite le canevas cartographique pour l'export image (exclut les
  // contrôles superposés : on n'exporte que la carte + ses calques).
  final _mapBoundaryKey = GlobalKey();
  double _zoom = 6.0;

  // Emprise (élargie d'un tampon) pour laquelle les étiquettes de localités ont
  // été calculées. Le dataset est dense (~7000 lieux GeoNames) → on ne construit
  // JAMAIS toutes les étiquettes : on les limite à la vue courante + un tampon,
  // et on ne recalcule que lorsque la vue déborde de ce tampon.
  LatLngBounds? _labelBounds;

  bool _viewEscapedLabelBounds(MapCamera cam) {
    final b = _labelBounds;
    if (b == null) return true;
    final v = cam.visibleBounds;
    return v.west < b.west ||
        v.east > b.east ||
        v.south < b.south ||
        v.north > b.north;
  }

  // Rebuild aux seuils de lisibilité (villes/bourgs/villages), à chaque
  // demi-niveau de zoom (clustering écoles), ET quand la vue sort du tampon
  // d'étiquettes en zoom rapproché (pour re-culler les localités au pan).
  void _onZoom(MapCamera camera, bool _) {
    final z = camera.zoom;
    final cross = (_zoom < 7.0) != (z < 7.0) ||
        (_zoom < 9.5) != (z < 9.5) ||
        (_zoom * 2).floor() != (z * 2).floor();
    final needCull = z >= 8.0 && _viewEscapedLabelBounds(camera);
    if (needCull) {
      final v = camera.visibleBounds;
      final dLat = (v.north - v.south) * 0.6;
      final dLng = (v.east - v.west) * 0.6;
      _labelBounds = LatLngBounds(
        LatLng(v.south - dLat, v.west - dLng),
        LatLng(v.north + dLat, v.east + dLng),
      );
    }
    _zoom = z;
    if ((cross || needCull) && mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Zoom incrémental (boutons +/−) borné à la plage de la carte.
  void _zoomBy(double delta) {
    final c = _mapController.camera;
    _mapController.move(c.center, (c.zoom + delta).clamp(5.8, 19.0));
  }

  // Recadre sur l'emprise nationale du Congo (bouton « accueil »).
  void _recenter() => _mapController.fitCamera(
        CameraFit.bounds(bounds: _kCongoBounds, padding: const EdgeInsets.all(28)),
      );

  // Bascule l'outil de mesure ; désactive le placement (modes exclusifs) et
  // repart d'une mesure vierge à chaque (dés)activation.
  void _toggleMeasure() {
    final on = !ref.read(_measureModeProv);
    ref.read(_measureModeProv.notifier).state = on;
    ref.read(_measurePointsProv.notifier).state = const [];
    if (on) ref.read(_placementModeProv.notifier).state = false;
  }

  // Capture le canevas cartographique courant en PNG et l'enregistre dans le
  // dossier Téléchargements (repli : dossier temporaire), puis l'ouvre. Sert à
  // joindre une vue territoriale datée à un rapport / une note gouvernementale.
  Future<void> _exportImage() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final boundary = _mapBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();

      final dir = await getDownloadsDirectory() ??
          await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/carte_territoriale_$stamp.png');
      await file.writeAsBytes(bytes);
      await launchUrl(Uri.file(file.path));

      messenger?.showSnackBar(SnackBar(
        content: Text('Carte exportée : ${file.path}'),
        backgroundColor: kGreen,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
        content: Text('Échec de l’export : $e'),
        backgroundColor: kRed,
      ));
    }
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

  // Localités par niveau de détail (LOD). Trois familles, seuils de zoom
  // distincts pour montrer les noms tôt sans saturer la carte :
  //   • villages + localités  → étiquette dès z≥8 (le long des routes)
  //   • hameaux + écarts       → point dès z≥8, étiquette de près (z≥10.5)
  //   • quartiers urbains      → point z≥11, étiquette au plus près (z≥12.5)
  List<Widget> _localityLayers(List<GeoPlace> places, bool onSat) {
    if (places.isEmpty) return const [];
    final villages = <GeoPlace>[];
    final hamlets  = <GeoPlace>[];
    final quarters = <GeoPlace>[];
    for (final p in places) {
      final t = p.type;
      if (t == 'village' || t == 'locality') {
        villages.add(p);
      } else if (t == 'hamlet' || t == 'isolated_dwelling') {
        hamlets.add(p);
      } else if (t == 'suburb' || t == 'neighbourhood' || t == 'quarter') {
        quarters.add(p);
      }
    }

    // Ne garde que les localités dans le tampon d'étiquettes (perf : dataset
    // dense). Sans tampon connu (1ʳᵉ frame), on ne restreint pas.
    final b = _labelBounds;
    bool inView(GeoPlace p) => b == null || b.contains(p.coords);

    Marker label(GeoPlace p, String type, double perChar) => Marker(
          point: p.coords,
          width: (p.name.length * perChar + 10).clamp(40, 110),
          height: 22,
          child: _PlaceMarker(name: p.name, type: type, onSatellite: onSat),
        );
    final dotColor = (onSat ? Colors.white : kTextMuted).withValues(alpha: 0.7);
    CircleMarker dot(GeoPlace p, double r, Color c) => CircleMarker(
          point: p.coords,
          radius: r,
          color: c,
          borderStrokeWidth: 0.8,
          borderColor: Colors.white.withValues(alpha: 0.6),
        );

    final layers = <Widget>[];
    // Villages & localités : point en vue départementale, nom dès z≥9 (culé).
    if (_zoom >= 9.0) {
      layers.add(MarkerLayer(markers: [
        for (final p in villages)
          if (inView(p)) label(p, 'village', 4.6),
      ]));
    } else {
      layers.add(CircleLayer(
          circles: [for (final p in villages) dot(p, 3.0, dotColor)]));
    }
    // Hameaux / écarts (très nombreux) : point dès z≥8.5, nom au plus près z≥11.
    if (_zoom >= 11.0) {
      layers.add(MarkerLayer(markers: [
        for (final p in hamlets)
          if (inView(p)) label(p, 'village', 4.2),
      ]));
    } else if (_zoom >= 8.5) {
      layers.add(CircleLayer(
          circles: [for (final p in hamlets) dot(p, 2.2, dotColor)]));
    }
    // Quartiers urbains : point z≥11, nom au plus près z≥12.5.
    if (_zoom >= 12.5) {
      layers.add(MarkerLayer(markers: [
        for (final p in quarters)
          if (inView(p)) label(p, 'quarter', 4.4),
      ]));
    } else if (_zoom >= 11.0) {
      layers.add(CircleLayer(circles: [
        for (final p in quarters) dot(p, 2.6, _kPurple.withValues(alpha: 0.8)),
      ]));
    }
    return layers;
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
    final measureMode      = ref.watch(_measureModeProv);
    final measurePoints    = ref.watch(_measurePointsProv);
    final onSatellite      = tileStyle != _TileStyle.standard;
    // Imagerie satellite datée (Wayback) : on ne charge la liste des versions
    // que si un fond satellite est actif. `index = -1` → imagerie la plus récente.
    final waybackIndex     = ref.watch(_waybackIndexProv);
    final releases         = onSatellite
        ? (ref.watch(waybackReleasesProvider).valueOrNull ??
            const <WaybackRelease>[])
        : const <WaybackRelease>[];
    final useWayback       = waybackIndex >= 0 && waybackIndex < releases.length;
    const esriImageryTmpl =
        'https://server.arcgisonline.com/ArcGIS/rest/services/'
        'World_Imagery/MapServer/tile/{z}/{y}/{x}';
    final satelliteUrl     = useWayback
        ? releases[waybackIndex].tileUrlTemplate
        : esriImageryTmpl;
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
      RepaintBoundary(
      key: _mapBoundaryKey,
      child: MouseRegion(
      cursor: isPlacement || measureMode
          ? SystemMouseCursors.precise
          : MouseCursor.defer,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // Adapte automatiquement le zoom au Congo quelle que soit la taille
          // de l'écran — plus fiable que fixer un initialZoom statique.
          initialCameraFit: CameraFit.bounds(
            bounds: _kCongoBounds,
            padding: const EdgeInsets.all(28),
          ),
          minZoom: 5.8,
          // Jusqu'à z19 : permet de descendre au niveau des toits et des ruelles
          // sur l'imagerie satellite (Brazzaville, Pointe-Noire…).
          maxZoom: 19,
          cameraConstraint: const CameraConstraint.unconstrained(),
          onPositionChanged: _onZoom,
          // Lecture des coordonnées sous le curseur (repère administratif).
          onPointerHover: (_, latlng) =>
              ref.read(_hoverCoordProv.notifier).state = latlng,
          onTap: (_, latlng) {
            // Outil de mesure : chaque clic ajoute un sommet à la ligne.
            if (measureMode) {
              ref.read(_measurePointsProv.notifier).state = [
                ...ref.read(_measurePointsProv),
                latlng,
              ];
              return;
            }
            if (isPlacement) {
              // Garde-fou : un projet DOIT être placé sur le territoire congolais.
              // Un clic hors des limites (océan, pays voisin) ne crée rien et
              // laisse le mode placement actif pour réessayer.
              if (!_isInCongoBounds(latlng)) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Point hors du Congo — placez le projet '
                        'sur le territoire national.'),
                    backgroundColor: kRed,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
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
              // Clé = URL → recharge les tuiles quand on déplace la frise datée.
              key: ValueKey(satelliteUrl),
              urlTemplate: satelliteUrl,
              userAgentPackageName: 'com.epilote.congo',
              // Masque le placeholder « Map data not yet available » : la tuile
              // de zoom inférieur transparaît (sur-zoom auto par lieu).
              // headers mutable : flutter_map y ajoute le User-Agent.
              tileProvider: EsriImageryTileProvider(headers: {}),
              keepBuffer: 6,
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
                // Table de ratios d'activité : nom normalisé → ratio [0..1] ou -1.
                // Basée sur TOUTES les écoles (GPS incluses) : sinon, dès que les
                // écoles sont géolocalisées, `depts` (écoles sans GPS) se vide, les
                // choroplèthes retombent tous transparents et les départements ne
                // paraissent plus « découpés ». (Même correctif que KPI/PDF.)
                final ratios = <String, double>{};
                for (final d in widget.data.allDepts) {
                  ratios[_normDept(d.dept)] = d.schoolCount > 0
                      ? d.activeCount / d.schoolCount
                      : 0.0;
                }
                return PolygonLayer(
                  // Frontières inter-départementales bien lisibles (trait plus
                  // épais et plus contrasté qu'un simple filet) → les 15 dépts
                  // sont visiblement découpés, avec ou sans données.
                  polygons: osmDepts.map((d) {
                    final ratio = ratios[_normDept(d.name)] ?? -1.0;
                    final fillColor = ratio < 0
                        ? Colors.transparent
                        : ratio >= 0.75
                            ? kGreen.withValues(alpha: 0.16)
                            : ratio >= 0.4
                                ? kNavy.withValues(alpha: 0.12)
                                : ratio > 0
                                    ? _kOrange.withValues(alpha: 0.16)
                                    : kRed.withValues(alpha: 0.12);
                    return Polygon(
                      points: d.outline,
                      color: fillColor,
                      borderStrokeWidth: 2.2,
                      borderColor: (tileStyle == _TileStyle.standard
                              ? kNavy
                              : Colors.white)
                          .withValues(alpha: tileStyle == _TileStyle.standard
                              ? 0.85
                              : 0.9),
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

          // ── Couche 3 : localités par niveau de détail (villages nommés dès le
          // zoom départemental, hameaux de plus près, quartiers urbains au plus
          // près). Rend enfin visibles les quartiers (suburb/neighbourhood/quarter)
          // et affiche les noms de villages plus tôt (repérage le long des routes).
          if (showVillages)
            ..._localityLayers(placesAsync.valueOrNull ?? const [], onSatellite),

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

          // Indicateur de chargement des données géo (Overpass 15-90 s).
          // Le réseau routier n'a pas de secours embarqué → feedback explicite
          // pour que le clic sur « Routes » ne paraisse pas sans effet.
          if (showRoads && roadsAsync.isLoading)
            const _GeoLoadingOverlay(
                label: 'Chargement du réseau routier… (15–90 s)')
          else if (boundaryAsync.isLoading ||
              polygonsAsync.isLoading ||
              placesAsync.isLoading)
            const _GeoLoadingOverlay()
          else if (showRoads &&
              (roadsAsync.hasError ||
                  (roadsAsync.hasValue && roadsAsync.value!.isEmpty)))
            const _GeoInfoBanner(
                icon: Icons.wifi_off_rounded,
                text: 'Réseau routier indisponible (OSM). Réessayez plus tard.'),

          // ── Outil de mesure : ligne + sommets cliqués ─────────────────────
          if (measureMode && measurePoints.isNotEmpty) ...[
            PolylineLayer(polylines: [
              Polyline(
                points: measurePoints,
                color: _kOrange,
                strokeWidth: 3,
                borderColor: Colors.white,
                borderStrokeWidth: 1,
              ),
            ]),
            MarkerLayer(
              markers: [
                for (final p in measurePoints)
                  Marker(
                    point: p,
                    width: 14,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Échelle métrique — repère indispensable pour un pilotage territorial
          // (apprécier les distances entre écoles/localités). Couleur adaptée au
          // fond (sombre sur satellite, navy sur carte).
          Scalebar(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 12),
            lineColor: tileStyle == _TileStyle.standard ? kNavy : Colors.white,
            strokeWidth: 2.5,
            textStyle: TextStyle(
              color: tileStyle == _TileStyle.standard ? kNavy : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

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
      ),
      // Contrôles de navigation + outils (zoom, recadrage, mesure, export).
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _MapControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onRecenter: _recenter,
            onMeasure: _toggleMeasure,
            measureActive: measureMode,
            onExport: _exportImage,
          ),
        ),
      ),
      // Lecture des coordonnées sous le curseur (repère administratif).
      const Positioned(top: 10, left: 10, child: _CoordReadout()),
      // Bandeau de l'outil de mesure (distance cumulée + annuler/effacer/fermer).
      if (measureMode)
        Positioned(
          top: 0, left: 0, right: 0,
          child: _MeasureBanner(
            points: measurePoints,
            onUndo: measurePoints.isEmpty
                ? null
                : () => ref.read(_measurePointsProv.notifier).state =
                    measurePoints.sublist(0, measurePoints.length - 1),
            onClear: () =>
                ref.read(_measurePointsProv.notifier).state = const [],
            onClose: _toggleMeasure,
          ),
        ),
      // Frise satellite datée (Esri Wayback) — seulement en fond satellite/hybride.
      if (onSatellite && releases.isNotEmpty)
        Positioned(
          left: 0, right: 0, bottom: 44,
          child: Center(
            child: _WaybackFrieze(
              releases: releases,
              index: waybackIndex,
              onChanged: (i) =>
                  ref.read(_waybackIndexProv.notifier).state = i,
            ),
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
