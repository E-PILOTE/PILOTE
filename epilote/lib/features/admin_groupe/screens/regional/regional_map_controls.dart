part of '../admin_regional_view.dart';

// Emprise nationale du Congo — source unique pour l'ajustement initial de la
// carte ET le bouton de recadrage.
final LatLngBounds _kCongoBounds =
    LatLngBounds(const LatLng(-5.2, 11.0), const LatLng(3.8, 18.8));

// ─── Contrôles de navigation (zoom + recadrage national) ─────────────────────
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onMeasure,
    required this.measureActive,
    required this.onExport,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback onMeasure;
  final bool measureActive;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback onTap,
        {bool top = false, bool bottom = false, bool active = false}) {
      final radius = BorderRadius.vertical(
        top: top ? const Radius.circular(8) : Radius.zero,
        bottom: bottom ? const Radius.circular(8) : Radius.zero,
      );
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? kNavy : null),
            child: Icon(icon, size: 18, color: active ? Colors.white : kNavy),
          ),
        ),
      );
    }

    Widget sep() => Container(height: 1, width: 36, color: kBorder);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: kCardBg,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          btn(Icons.add_rounded, 'Zoom avant', onZoomIn, top: true),
          sep(),
          btn(Icons.remove_rounded, 'Zoom arrière', onZoomOut),
          sep(),
          btn(Icons.home_rounded, 'Recadrer sur le Congo', onRecenter),
          sep(),
          btn(Icons.straighten_rounded, 'Mesurer une distance', onMeasure,
              active: measureActive),
          sep(),
          btn(Icons.image_rounded, 'Exporter l’image de la carte', onExport,
              bottom: true),
        ]),
      ),
    );
  }
}

// ─── Lecture des coordonnées sous le curseur ─────────────────────────────────
class _CoordReadout extends ConsumerWidget {
  const _CoordReadout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(_hoverCoordProv);
    if (p == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.my_location_rounded, size: 12, color: kNavy),
          const SizedBox(width: 6),
          Text(
            '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
                fontFamily: 'monospace'),
          ),
        ]),
      ),
    );
  }
}

// ─── Bandeau de l'outil de mesure de distance ────────────────────────────────
class _MeasureBanner extends StatelessWidget {
  const _MeasureBanner({
    required this.points,
    required this.onUndo,
    required this.onClear,
    required this.onClose,
  });
  final List<LatLng> points;
  final VoidCallback? onUndo;
  final VoidCallback onClear;
  final VoidCallback onClose;

  String _fmt(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km'
      : '${meters.round()} m';

  @override
  Widget build(BuildContext context) {
    const geo = Distance();
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += geo(points[i - 1], points[i]);
    }
    final label = points.length < 2
        ? 'Cliquez deux points ou plus pour mesurer'
        : 'Distance : ${_fmt(total)}  ·  ${points.length} points';
    return Material(
      color: _kOrange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          const Icon(Icons.straighten_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
          if (onUndo != null)
            _MeasureAction(
                icon: Icons.undo_rounded, label: 'Annuler', onTap: onUndo!),
          _MeasureAction(
              icon: Icons.clear_all_rounded, label: 'Effacer', onTap: onClear),
          _MeasureAction(
              icon: Icons.close_rounded, label: 'Terminer', onTap: onClose),
        ]),
      ),
    );
  }
}

class _MeasureAction extends StatelessWidget {
  const _MeasureAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 15, color: Colors.white),
          label: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
}

// ─── Frise satellite datée (Esri Wayback) sur la carte principale ────────────
class _WaybackFrieze extends StatelessWidget {
  const _WaybackFrieze({
    required this.releases,
    required this.index,
    required this.onChanged,
  });
  final List<WaybackRelease> releases;
  final int index; // -1 = imagerie la plus récente
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final useWayback = index >= 0 && index < releases.length;
    final dateLabel = useWayback
        ? DateFormat('MMM yyyy', 'fr').format(releases[index].date)
        : 'Imagerie la plus récente';
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 14, color: kNavy),
          const SizedBox(width: 6),
          Text('Imagerie satellite datée · $dateLabel',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: (index + 1).toDouble(),
            min: 0,
            max: releases.length.toDouble(),
            divisions: releases.length,
            activeColor: kNavy,
            label: useWayback
                ? DateFormat('yyyy-MM').format(releases[index].date)
                : 'Actuelle',
            onChanged: (v) => onChanged(v.round() - 1),
          ),
        ),
      ]),
    );
  }
}

// Boîte englobante du Congo (même emprise que l'ajustement initial de la carte).
// Sert de garde-fou au placement d'un projet.
bool _isInCongoBounds(LatLng p) =>
    p.latitude >= -5.2 &&
    p.latitude <= 3.8 &&
    p.longitude >= 11.0 &&
    p.longitude <= 18.8;

/// Département dont le centroïde est le plus proche du point donné, ou `null`
/// si la liste est vide. Distance en degrés² (suffisant à l'échelle du pays)
/// → sert à pré-remplir le département à la création d'un projet.
String? _nearestDeptName(List<GeoDepartment> depts, LatLng p) {
  String? best;
  var bestD = double.infinity;
  for (final d in depts) {
    final dLat = d.centroid.latitude - p.latitude;
    final dLng = d.centroid.longitude - p.longitude;
    final dist = dLat * dLat + dLng * dLng;
    if (dist < bestD) {
      bestD = dist;
      best = d.name;
    }
  }
  return best;
}

