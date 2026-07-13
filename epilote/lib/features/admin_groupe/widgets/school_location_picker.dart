import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/school_geocoder_provider.dart';
import 'esri_tile_provider.dart';

// ─── Bornes de la République du Congo (avec marge) ───────────────────────────
// Un point hors de ces bornes est presque sûrement une erreur (lat/lng inversées,
// signe oublié) — on le refuse pour préserver l'intégrité de la couche positionnelle.
const double _kLatMin = -5.2, _kLatMax = 3.8, _kLngMin = 11.0, _kLngMax = 18.8;
final LatLngBounds _kCongoBounds =
    LatLngBounds(const LatLng(_kLatMin, _kLngMin), const LatLng(_kLatMax, _kLngMax));
bool _inCongo(LatLng p) =>
    p.latitude >= _kLatMin && p.latitude <= _kLatMax &&
    p.longitude >= _kLngMin && p.longitude <= _kLngMax;

/// Valeur immuable : position d'une école + provenance.
/// `source` ∈ {'gps','geocoded','manual'} (contrainte CHECK en base).
class SchoolLocation {
  const SchoolLocation({required this.lat, required this.lng, required this.source});
  final double lat;
  final double lng;
  final String source;

  LatLng get latLng => LatLng(lat, lng);
  /// Un point saisi/relevé/déplacé est PRÉCIS ; un point géocodé (centroïde de
  /// localité) est APPROXIMATIF — la distinction guide l'affichage carte (SIG).
  bool get isPrecise => source == 'gps' || source == 'manual';

  @override
  bool operator ==(Object other) =>
      other is SchoolLocation &&
      other.lat == lat && other.lng == lng && other.source == source;

  @override
  int get hashCode => Object.hash(lat, lng, source);
}

/// Pont entre le formulaire (cascade Département→Localité) et la carte.
/// - Le formulaire appelle [requestApprox] quand une localité est choisie → la
///   carte vole dessus et y pose un repère APPROXIMATIF (`geocoded`).
/// - La carte écrit la position courante dans [value] (lue à la soumission).
class SchoolLocationController extends ChangeNotifier {
  SchoolLocationController([this.value]);

  /// Source de vérité de la position (mise à jour par la carte).
  SchoolLocation? value;

  // Signal one-shot : centrer la carte sur une localité choisie au formulaire.
  LatLng? _pendingApprox;
  LatLng? consumeApprox() {
    final p = _pendingApprox;
    _pendingApprox = null;
    return p;
  }

  /// Demande de recentrage + repère approximatif (depuis la cascade localité).
  void requestApprox(LatLng p) {
    _pendingApprox = p;
    notifyListeners();
  }

  /// Écriture silencieuse depuis la carte (pas de notify → évite les boucles).
  void writeFromMap(SchoolLocation? v) => value = v;
}

/// Sélecteur cartographique de la position d'une école (pattern « géocoder puis
/// affiner »). Facultatif, jamais bloquant.
/// - Cascade → [SchoolLocationController.requestApprox] centre la carte + pose ≈.
/// - Affinage : GLISSER le repère ou TOUCHER la carte le cale sur le bâtiment
///   (→ `manual`, précis) ; saisie numérique tolérée (copier-coller de relevé).
class SchoolLocationField extends ConsumerStatefulWidget {
  const SchoolLocationField({
    super.key,
    required this.controller,
    required this.cityName,
  });

  final SchoolLocationController controller;
  /// Ville courante du formulaire (lue au clic « Centrer sur la ville »).
  final String Function() cityName;

  @override
  ConsumerState<SchoolLocationField> createState() => _SchoolLocationFieldState();
}

class _SchoolLocationFieldState extends ConsumerState<SchoolLocationField> {
  final _map = MapController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  LatLng? _point;
  String _source = 'manual';
  // Fond : 'map' (OSM étiqueté, défaut — noms/routes visibles), 'satellite'
  // (imagerie brute) ou 'hybrid' (imagerie + noms).
  String _base = 'map';
  // Vrai pendant qu'on glisse le repère → on coupe le pan de la carte pour que
  // le geste aille au repère et non au déplacement de la carte (arène de gestes).
  bool _pinHot = false;

  @override
  void initState() {
    super.initState();
    final i = widget.controller.value;
    if (i != null) {
      _point = i.latLng;
      _source = i.source;
      _latCtrl.text = i.lat.toStringAsFixed(6);
      _lngCtrl.text = i.lng.toStringAsFixed(6);
    }
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _map.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  // Le formulaire a choisi une localité → repère approximatif + vol de caméra.
  void _onController() {
    final p = widget.controller.consumeApprox();
    if (p != null) _setPoint(p, 'geocoded', moveCamera: true);
  }

  void _setPoint(LatLng p, String source, {bool moveCamera = false}) {
    setState(() {
      _point = p;
      _source = source;
      _latCtrl.text = p.latitude.toStringAsFixed(6);
      _lngCtrl.text = p.longitude.toStringAsFixed(6);
    });
    widget.controller.writeFromMap(
        SchoolLocation(lat: p.latitude, lng: p.longitude, source: source));
    if (moveCamera) {
      final z = _map.camera.zoom;
      _map.move(p, z < 13 ? 14 : z);
    }
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? kRed : kGreen,
        duration: const Duration(seconds: 2),
      ));

  void _onTap(LatLng p) {
    if (!_inCongo(p)) {
      _snack('Point hors du Congo — placez l\'école sur le territoire national.');
      return;
    }
    _setPoint(p, 'manual');
  }

  // Glisser-déposer : convertit le déplacement écran en déplacement géographique
  // via la caméra courante (pas de dépendance externe).
  void _onPanUpdate(DragUpdateDetails d) {
    if (_point == null) return;
    final cam = _map.camera;
    final cur = cam.latLngToScreenPoint(_point!);
    final next = math.Point(cur.x + d.delta.dx, cur.y + d.delta.dy);
    final ll = cam.pointToLatLng(next);
    if (_inCongo(ll)) _setPoint(ll, 'manual');
  }

  void _useCity() {
    final city = widget.cityName().trim();
    if (city.isEmpty) {
      _snack('Renseignez d\'abord la localité pour la centrer automatiquement.');
      return;
    }
    final places = ref.read(congoPlacesProvider).valueOrNull ?? const [];
    final coords = geocodeCity(places, city);
    if (coords == null) {
      _snack('« $city » introuvable dans le référentiel des localités.');
      return;
    }
    _setPoint(coords, 'geocoded', moveCamera: true);
    _snack('Position approximative (centre de « $city »). Affinez sur la carte.',
        error: false);
  }

  void _clear() {
    setState(() {
      _point = null;
      _latCtrl.clear();
      _lngCtrl.clear();
    });
    widget.controller.writeFromMap(null);
  }

  void _applyManual() {
    final lat = double.tryParse(_latCtrl.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lngCtrl.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null) return;
    final p = LatLng(lat, lng);
    if (!_inCongo(p)) {
      _snack('Coordonnées hors Congo (lat $_kLatMin…$_kLatMax, lng $_kLngMin…$_kLngMax).');
      return;
    }
    _setPoint(p, 'manual', moveCamera: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _statusChip()),
        const SizedBox(width: 8),
        _mapToggle(),
      ]),
      const SizedBox(height: 10),
      _mapBox(),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _numField(_latCtrl, 'Latitude', hint: 'ex. -4.263000')),
        const SizedBox(width: 10),
        Expanded(child: _numField(_lngCtrl, 'Longitude', hint: 'ex. 15.242900')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _actionBtn(Icons.my_location_rounded, 'Centrer sur la localité', _useCity),
        const SizedBox(width: 8),
        if (_point != null)
          _actionBtn(Icons.layers_clear_rounded, 'Effacer', _clear, subtle: true),
        const Spacer(),
        _actionBtn(Icons.check_rounded, 'Appliquer', _applyManual, subtle: true),
      ]),
      const SizedBox(height: 8),
      const Row(children: [
        Icon(Icons.info_outline_rounded, size: 13, color: kTextMuted),
        SizedBox(width: 6),
        Expanded(child: Text(
          'Choisissez département puis localité ci-dessus : le repère se pose '
          'automatiquement. Glissez-le (ou touchez la carte, idéalement en '
          'satellite) pour le caler sur le bâtiment exact.',
          style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.35),
        )),
      ]),
    ]);
  }

  // ── Sous-widgets ───────────────────────────────────────────────────────────

  Widget _statusChip() {
    final (IconData icon, String label, Color color) = _point == null
        ? (Icons.location_off_rounded, 'Non localisée', kTextMuted)
        : _source == 'geocoded'
            ? (Icons.location_searching_rounded, 'Approximative (localité)', const Color(0xFFB45309))
            : (Icons.where_to_vote_rounded, 'Précise (repère calé)', kGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }

  Widget _mapToggle() {
    Widget seg(String label, String value) {
      final on = _base == value;
      return GestureDetector(
        onTap: () => setState(() => _base = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: on ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: on ? Colors.white : kTextMuted)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Carte', 'map'),
        seg('Satellite', 'satellite'),
        seg('Hybride', 'hybrid'),
      ]),
    );
  }

  Widget _mapBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 240,
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: _point != null
                  ? CameraFit.coordinates(
                      coordinates: [_point!],
                      padding: const EdgeInsets.all(120),
                      maxZoom: 15)
                  : CameraFit.bounds(
                      bounds: _kCongoBounds, padding: const EdgeInsets.all(16)),
              minZoom: 5.5,
              maxZoom: 19,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    (_pinHot ? InteractiveFlag.none : InteractiveFlag.drag) |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
              onTap: (_, latlng) => _onTap(latlng),
            ),
            children: [
              // Fond « Carte » : OpenStreetMap (villes, villages, routes, noms).
              if (_base == 'map')
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.epilote.congo',
                  maxZoom: 19,
                ),
              // Fonds satellite / hybride : imagerie Esri (usage libre, sans clé).
              if (_base != 'map')
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/'
                      'World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.epilote.congo',
                  tileProvider: EsriImageryTileProvider(headers: {}),
                  maxNativeZoom: 19,
                  maxZoom: 19,
                ),
              // Hybride : étiquettes (villes, routes, limites) par-dessus l'imagerie.
              if (_base == 'hybrid')
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/'
                      'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.epilote.congo',
                  maxNativeZoom: 18,
                  maxZoom: 19,
                ),
              if (_point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _point!,
                    width: 46,
                    height: 46,
                    alignment: Alignment.topCenter, // pointe du pin sur la coordonnée
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      // Listener : dès le pointeur posé sur le repère, on « chauffe »
                      // (coupe le pan carte) AVANT que l'arène ne tranche → le
                      // glisser va bien au repère. Réinitialisé au relâcher.
                      child: Listener(
                        onPointerDown: (_) {
                          if (!_pinHot) setState(() => _pinHot = true);
                        },
                        onPointerUp: (_) {
                          if (_pinHot) setState(() => _pinHot = false);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: _onPanUpdate,
                          child: _Pin(precise: _source != 'geocoded'),
                        ),
                      ),
                    ),
                  ),
                ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('Esri, OpenStreetMap', onTap: null),
              ]),
            ],
          ),
          if (_point == null)
            const IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: _Hint('Choisissez une localité, ou touchez la carte'),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {required String hint}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
      onFieldSubmitted: (_) => _applyManual(),
      style: const TextStyle(fontSize: 13),
      decoration: adminInputDecoration(label, hint: hint),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {bool subtle = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: subtle ? kSurface : kNavy.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: subtle ? kBorder : kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: subtle ? kTextMuted : kNavy),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700,
                color: subtle ? kTextMuted : kNavy)),
          ]),
        ),
      ),
    );
  }
}

// Repère : pin plein vert = position précise ; contour ambre = approximative.
class _Pin extends StatelessWidget {
  const _Pin({required this.precise});
  final bool precise;

  @override
  Widget build(BuildContext context) {
    final color = precise ? kGreen : const Color(0xFFB45309);
    return Stack(alignment: Alignment.center, children: [
      Icon(Icons.location_on, size: 44, color: Colors.black.withValues(alpha: 0.28)),
      Icon(precise ? Icons.location_on : Icons.location_on_outlined,
          size: 40, color: color),
      Positioned(
        top: 9,
        child: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    ]);
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.touch_app_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      );
}
