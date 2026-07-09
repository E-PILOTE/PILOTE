import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/admin_ui.dart'
    show kNavy, kTextMuted, kTextPrimary;
import '../providers/wayback_provider.dart';

const _esriCurrent =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
    'MapServer/tile/{z}/{y}/{x}';

/// Vue satellite d'un point (école / site de projet) : imagerie Esri courante +
/// frise datée Esri Wayback (curseur). Aucune clé API, aucun coût. Dégrade
/// proprement hors-ligne (garde l'imagerie courante, masque la frise).
///
/// NB : l'imagerie satellite n'est jamais « live » — ce sont des clichés datés.
class SchoolSatelliteView extends ConsumerStatefulWidget {
  const SchoolSatelliteView({
    super.key,
    required this.center,
    this.title,
    this.height = 240,
  });
  final LatLng center;
  final String? title;
  final double height;

  @override
  ConsumerState<SchoolSatelliteView> createState() =>
      _SchoolSatelliteViewState();
}

class _SchoolSatelliteViewState extends ConsumerState<SchoolSatelliteView> {
  int _releaseIndex = -1; // -1 = imagerie courante (non datée)

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(waybackReleasesProvider).valueOrNull ?? const [];
    final useWayback = _releaseIndex >= 0 && _releaseIndex < releases.length;
    final urlTemplate =
        useWayback ? releases[_releaseIndex].tileUrlTemplate : _esriCurrent;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: widget.height,
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.center,
                initialZoom: 17,
                minZoom: 12,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  key: ValueKey(urlTemplate),
                  urlTemplate: urlTemplate,
                  userAgentPackageName: 'com.epilote.congo',
                  maxNativeZoom: 19,
                  maxZoom: 19,
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.center,
                    width: 34,
                    height: 34,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 34),
                  ),
                ]),
              ],
            ),
            // Attribution (obligatoire Esri).
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: Colors.black38,
                child: const Text('Esri, Maxar',
                    style: TextStyle(color: Colors.white, fontSize: 8)),
              ),
            ),
          ]),
        ),
      ),
      if (releases.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.history_rounded, size: 14, color: kTextMuted),
          const SizedBox(width: 6),
          Text(
            useWayback
                ? 'Imagerie du ${DateFormat('MMM yyyy', 'fr').format(releases[_releaseIndex].date)}'
                : 'Imagerie la plus récente',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
        ]),
        Slider(
          value: (_releaseIndex + 1).toDouble(),
          min: 0,
          max: releases.length.toDouble(),
          divisions: releases.length,
          activeColor: kNavy,
          label: useWayback
              ? DateFormat('yyyy-MM').format(releases[_releaseIndex].date)
              : 'Actuelle',
          onChanged: (v) => setState(() => _releaseIndex = v.round() - 1),
        ),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Frise datée indisponible (hors-ligne).',
              style: TextStyle(fontSize: 10, color: kTextMuted)),
        ),
    ]);
  }
}
