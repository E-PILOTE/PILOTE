import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../providers/mapillary_provider.dart';
import 'admin_ui.dart';

/// Panneau « Vue rue » intégré : affiche les photos Mapillary au sol les plus
/// proches d'un point, défilables. Aucune redirection navigateur.
class MapillaryViewerDialog extends ConsumerStatefulWidget {
  const MapillaryViewerDialog({super.key, required this.center});
  final LatLng center;

  @override
  ConsumerState<MapillaryViewerDialog> createState() =>
      _MapillaryViewerDialogState();
}

class _MapillaryViewerDialogState extends ConsumerState<MapillaryViewerDialog> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final key = (lat: widget.center.latitude, lng: widget.center.longitude);
    final async = ref.watch(mapillaryNearbyProvider(key));

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                const Icon(Icons.streetview_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Vue rue · imagerie au sol',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Flexible(
              child: async.when(
                loading: () => const _Centered(
                  icon: null,
                  text: 'Recherche des photos au sol…',
                  spinner: true,
                ),
                error: (e, _) => _Centered(
                  icon: Icons.cloud_off_rounded,
                  color: kRed,
                  text: 'Imagerie indisponible (réseau).',
                  action: ('Réessayer', () {
                    ref.invalidate(mapillaryNearbyProvider(key));
                  }),
                ),
                data: (imgs) {
                  if (imgs.isEmpty) {
                    return const _Centered(
                      icon: Icons.location_off_rounded,
                      text:
                          'Aucune photo de rue à cet endroit.\nLa couverture Mapillary se limite surtout aux axes\nprincipaux de Brazzaville et Pointe-Noire.',
                    );
                  }
                  final i = _i.clamp(0, imgs.length - 1);
                  return _Viewer(
                    images: imgs,
                    index: i,
                    center: widget.center,
                    onPrev: i > 0 ? () => setState(() => _i = i - 1) : null,
                    onNext: i < imgs.length - 1
                        ? () => setState(() => _i = i + 1)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({
    required this.images,
    required this.index,
    required this.center,
    required this.onPrev,
    required this.onNext,
  });
  final List<MapillaryImage> images;
  final int index;
  final LatLng center;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final img = images[index];
    const distance = Distance();
    final meters = distance(center, img.coords).round();
    final date = img.capturedAt != null
        ? DateFormat('d MMM yyyy', 'fr').format(img.capturedAt!)
        : 'date inconnue';

    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF111418),
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  img.thumbUrl,
                  key: ValueKey(img.id),
                  fit: BoxFit.contain,
                  // Décodage borné à 1280 px → réduit fortement la mémoire
                  // texture GPU (pilote Nouveau Linux fragile sur gros frames).
                  cacheWidth: 1280,
                  gaplessPlayback: true,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                  errorBuilder: (ctx, _, _) => const Center(
                    child: Text('Image illisible',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
                if (onPrev != null)
                  Positioned(
                    left: 8,
                    child: _NavArrow(
                        icon: Icons.chevron_left_rounded, onTap: onPrev!),
                  ),
                if (onNext != null)
                  Positioned(
                    right: 8,
                    child: _NavArrow(
                        icon: Icons.chevron_right_rounded, onTap: onNext!),
                  ),
              ],
            ),
          ),
        ),
        // Pied : date, distance, position
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: kBorder)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(children: [
            const Icon(Icons.photo_camera_back_rounded,
                size: 15, color: kTextMuted),
            const SizedBox(width: 6),
            Text('Prise le $date',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            const SizedBox(width: 12),
            const Icon(Icons.straighten_rounded, size: 15, color: kTextMuted),
            const SizedBox(width: 4),
            Text('à $meters m',
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
            const Spacer(),
            Text('${index + 1} / ${images.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kNavy)),
          ]),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.text,
    this.icon,
    this.color = kTextMuted,
    this.spinner = false,
    this.action,
  });
  final String text;
  final IconData? icon;
  final Color color;
  final bool spinner;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const CircularProgressIndicator(color: kNavy, strokeWidth: 2.5)
            else if (icon != null)
              Icon(icon, size: 40, color: color),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: color)),
            if (action != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: action!.$2,
                child: Text(action!.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
