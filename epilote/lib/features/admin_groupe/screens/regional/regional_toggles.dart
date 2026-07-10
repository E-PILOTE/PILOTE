part of '../admin_regional_view.dart';

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
                tooltip: 'Assombrit tout ce qui est hors du Congo pour '
                    'concentrer la carte sur le pays.',
                onTap: () =>
                    ref.read(_showMaskLayerProv.notifier).state = !showMask),
            _FilterChip(
                label: 'Depts',
                icon: Icons.crop_square_rounded,
                active: showPolygons,
                color: kNavy,
                tooltip: 'Contours des 15 départements du Congo, colorés selon '
                    'le taux d’écoles actives (choroplèthe).',
                onTap: () =>
                    ref.read(_showPolygonsLayerProv.notifier).state = !showPolygons),
            _FilterChip(
                label: 'Pôles',
                icon: Icons.map_rounded,
                active: showDept,
                color: _kBlue,
                tooltip: 'Bulle par département indiquant le nombre d’écoles '
                    'agrégées (écoles sans position GPS précise).',
                onTap: () =>
                    ref.read(_showDeptLayerProv.notifier).state = !showDept),
            _FilterChip(
                label: 'GPS',
                icon: Icons.gps_fixed_rounded,
                active: showGps,
                color: kGreen,
                tooltip: 'Écoles géolocalisées, positionnées précisément à leur '
                    'emplacement réel.',
                onTap: () =>
                    ref.read(_showGpsLayerProv.notifier).state = !showGps),
            _FilterChip(
                label: 'Projets',
                icon: Icons.business_center_rounded,
                active: showProj,
                color: _kOrange,
                tooltip: 'Projets de construction de nouvelles écoles '
                    '(pipeline d’expansion).',
                onTap: () =>
                    ref.read(_showProjLayerProv.notifier).state = !showProj),
            _FilterChip(
                label: 'Villes',
                icon: Icons.location_city_rounded,
                active: showCities,
                color: _kBlue,
                tooltip: 'Villes et bourgs principaux, comme repères '
                    '(toujours visibles).',
                onTap: () =>
                    ref.read(_showCitiesLayerProv.notifier).state = !showCities),
            _FilterChip(
                label: 'Villages',
                icon: Icons.holiday_village_rounded,
                active: showVillages,
                color: _kPurple,
                tooltip: 'Villages, hameaux et quartiers urbains (OSM). Noms '
                    'affichés progressivement selon le zoom — embarqués, '
                    'donc instantanés.',
                onTap: () =>
                    ref.read(_showVillagesLayerProv.notifier).state = !showVillages),
            _FilterChip(
                label: 'Routes',
                icon: Icons.route_rounded,
                active: showRoads,
                color: const Color(0xFFF59E0B),
                tooltip: 'Réseau routier national (axes principaux). Chargé '
                    'depuis OpenStreetMap — peut prendre 15 à 90 s.',
                onTap: () {
                  ref.read(_showRoadsLayerProv.notifier).state = !showRoads;
                  // Déclenche le chargement la 1ère fois qu'on active
                  if (!showRoads) ref.read(congoRoadsProvider);
                }),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 8),
          // ── Coloration des écoles ──────────────────────────────────────────
          const Row(children: [
            Icon(Icons.palette_outlined, size: 13, color: kTextMuted),
            SizedBox(width: 6),
            Text('COULEUR DES ÉCOLES', style: sectionLabel),
          ]),
          const SizedBox(height: 6),
          const _PinColorSwitch(),
        ],
      ),
    );
  }
}

// Segmenté : colorer les pins/grappes par type ou par charge (élèves/classe).
class _PinColorSwitch extends ConsumerWidget {
  const _PinColorSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_pinColorModeProv);
    Widget btn(String label, IconData icon, _PinColorMode m, String tip,
        {bool first = false, bool last = false}) {
      final active = mode == m;
      final radius = BorderRadius.horizontal(
          left: first ? const Radius.circular(6) : Radius.zero,
          right: last ? const Radius.circular(6) : Radius.zero);
      return Expanded(
        child: Tooltip(
          message: tip,
          waitDuration: const Duration(milliseconds: 400),
          preferBelow: false,
          child: InkWell(
          onTap: () => ref.read(_pinColorModeProv.notifier).state = m,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? kNavy : Colors.transparent,
              borderRadius: radius,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 13, color: active ? Colors.white : kTextMuted),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : kTextMuted)),
            ]),
          ),
        ),
        ),
      );
    }

    Widget sep() => Container(width: 1, height: 26, color: kBorder);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(children: [
        btn('Type', Icons.category_outlined, _PinColorMode.type,
            'Colore les écoles selon leur type : publique, privée ou mixte.',
            first: true),
        sep(),
        btn('Charge', Icons.groups_2_outlined, _PinColorMode.load,
            'Colore les écoles selon la charge pédagogique '
            '(nombre d’élèves par classe). Rouge = surchargée.'),
        sep(),
        btn('Occup.', Icons.event_seat_outlined, _PinColorMode.occupancy,
            'Colore les écoles selon le taux d’occupation '
            '(effectif ÷ capacité). Rouge = sur-occupée.',
            last: true),
      ]),
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
    this.tooltip,
  });
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = MouseRegion(
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
    if (tooltip == null) return chip;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 400),
      preferBelow: false,
      child: chip,
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

