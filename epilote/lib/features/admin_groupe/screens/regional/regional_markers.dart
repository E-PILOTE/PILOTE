part of '../admin_regional_view.dart';

// ─── Disque d'un marqueur école ──────────────────────────────────────────────
// Répartition des variables visuelles (règle de sémiologie cartographique) :
//   • la COULEUR encode l'ÉTAT (type / charge / occupation / inactive) → elle
//     est légendable, donc lisible par tous ; elle ne doit JAMAIS servir
//     d'identifiant d'école (l'œil ne distingue pas 20 teintes arbitraires).
//   • l'IDENTITÉ de l'école est portée par son LOGO (+ son nom sous le pin),
//     exactement comme un établissement sur Google Maps. Sans logo → icône
//     générique sur fond coloré (repli).
//   • le badge « ≈ » signale une position approximative (centroïde de ville).
class _SchoolMarkerDisc extends StatelessWidget {
  const _SchoolMarkerDisc({
    required this.size,
    required this.color,
    required this.approx,
    required this.selected,
    this.logoUrl,
  });

  final double size;
  final Color color;
  final bool approx;
  final bool selected;
  final String? logoUrl;

  bool get _hasLogo => logoUrl != null && logoUrl!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final ring = selected ? 3.0 : 2.2;
    final shadow = [
      BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 3)),
    ];

    // Avec logo : pastille blanche cerclée de la couleur d'état (l'anneau reste
    // le signal analytique, le cœur devient la signature de l'école).
    // Sans logo : disque plein coloré + icône école.
    final Widget disc = _hasLogo
        ? Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(ring * 0.6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: ring),
              boxShadow: shadow,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => ColoredBox(
                    color: color.withValues(alpha: 0.15), child: const SizedBox()),
                errorWidget: (_, _, _) =>
                    Icon(Icons.school_rounded, color: color, size: size * 0.42),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: approx ? 0.55 : 0.9),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white, width: selected ? 2.5 : 2.0),
              boxShadow: shadow,
            ),
            child: Icon(Icons.school_rounded,
                color: Colors.white, size: size * 0.46),
          );

    return Stack(clipBehavior: Clip.none, children: [
      // Position approximative → disque atténué (jamais de fausse précision).
      approx ? Opacity(opacity: 0.75, child: disc) : disc,
      if (approx)
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.4),
            ),
            child: Text('≈',
                style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ),
        ),
    ]);
  }
}

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
    final isQuarter = type == 'quarter'; // suburb / neighbourhood / quarter
    final dotColor  = isCity
        ? const Color(0xFF0EA5E9)   // bleu ciel
        : isTown
            ? const Color(0xFF10B981) // vert émeraude
            : isQuarter
                ? const Color(0xFF7C3AED) // violet (subdivision urbaine)
                : const Color(0xFF94A3B8); // ardoise (village/hameau)
    final dotSize   = isCity ? 11.0 : isTown ? 7.5 : isQuarter ? 5.0 : 4.5;
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
  const _GeoLoadingOverlay(
      {this.label = 'Chargement des données cartographiques OSM…'});
  final String label;

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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 1.8),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// Bandeau d'information en haut de la carte (couche indisponible, etc.).
class _GeoInfoBanner extends StatelessWidget {
  const _GeoInfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = kRed;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 7),
            Text(text,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: c)),
          ]),
        ),
      ),
    );
  }
}

// ─── Légende ────────────────────────────────────────────────────────────────
class _MapLegend extends ConsumerWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinMode = ref.watch(_pinColorModeProv);
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
            Text(label, style: TextStyle(fontSize: 9, color: kTextPrimary)),
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
            Text('LÉGENDE',
                style: TextStyle(
                    fontSize: 8.5, fontWeight: FontWeight.w800,
                    color: kTextMuted, letterSpacing: 1.0)),
            // Choroplèthe
            const SizedBox(height: 3),
            Text('CHOROPLÈTHE',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            row(colorBox(kGreen,   0.16), '≥ 75 % actives'),
            row(colorBox(kNavy,    0.12), '40–74 %'),
            row(colorBox(_kOrange, 0.16), '< 40 %'),
            row(colorBox(kRed,     0.12), '0 % active'),
            // Écoles
            const SizedBox(height: 3),
            Text('ÉCOLES & PROJETS',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            if (pinMode == _PinColorMode.type) ...[
              row(circle(_kBlue, 11), 'École GPS (publique)'),
              row(circle(kGreen, 11), 'École GPS (privée)'),
              row(circle(_kPurple, 11), 'École GPS (mixte)'),
            ] else if (pinMode == _PinColorMode.load) ...[
              row(circle(kGreen, 11), 'Effectifs maîtrisés (<40/cl.)'),
              row(circle(const Color(0xFFF59E0B), 11), 'Classes chargées (40–49)'),
              row(circle(kRed, 11), 'Classes surchargées (≥50)'),
              row(circle(kTextMuted, 11), 'Charge inconnue'),
            ] else ...[
              row(circle(const Color(0xFFF59E0B), 11), 'Sous-occupée (<70 %)'),
              row(circle(kGreen, 11), 'Occupation optimale (70–99 %)'),
              row(circle(kRed, 11), 'Capacité saturée (≥100 %)'),
              row(circle(kTextMuted, 11), 'Capacité non renseignée'),
            ],
            row(circle(kRed, 11), 'École inactive'),
            row(
              Container(
                width: 11, height: 11,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kTextMuted.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text('≈', style: TextStyle(
                    fontSize: 7, height: 1,
                    fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              'Position approximative (ville)',
            ),
            row(
              Row(mainAxisSize: MainAxisSize.min, children: [
                circle(kNavy, 9),
                const SizedBox(width: 1),
                circle(kNavy, 14),
              ]),
              'Grappe (zoom < 9.5) · nb écoles',
            ),
            row(sq(_kOrange, 10), 'Projet en cours'),
            row(sq(kGreen, 10), 'Projet achevé'),
            // Localités
            const SizedBox(height: 3),
            Text('LOCALITÉS',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            row(circle(const Color(0xFF0EA5E9), 10), 'Ville (toujours visible)'),
            row(circle(const Color(0xFF10B981),  8), 'Bourg (zoom ≥ 7)'),
            row(circle(const Color(0xFF94A3B8),  6), 'Village (nom ≥ z9) · hameau (≥ z11)'),
            row(circle(const Color(0xFF7C3AED),  6), 'Quartier urbain (zoom ≥ 12)'),
          ]),
    );
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
            SizedBox(
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
class _StreetViewFab extends ConsumerWidget {
  const _StreetViewFab({required this.controller});
  final MapController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ref.read(_streetViewCenterProv.notifier).state =
            controller.camera.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.streetview_rounded, size: 16, color: kNavy),
            const SizedBox(width: 6),
            Text('Vue rue',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

