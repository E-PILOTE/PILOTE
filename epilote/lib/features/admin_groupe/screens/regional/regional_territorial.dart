part of '../admin_regional_view.dart';

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
          Text('ANALYSE TERRITORIALE',
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
          child: Row(children: [
            Icon(Icons.location_off_rounded, size: 18, color: kAccent),
            const SizedBox(width: 10),
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
      Text('ÉCOLES LES PLUS ISOLÉES',
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
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(
                          s.nearestSchoolKm != null
                              ? 'École voisine : ${_fmtKm(s.nearestSchoolKm)} · ${s.nearestCity} ${_fmtKm(s.nearestCityKm)}'
                              : '${s.nearestCity} ${_fmtKm(s.nearestCityKm)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
          Icon(Icons.info_outline_rounded, size: 13, color: kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${report.gpsSchools}/${report.totalSchools} écoles avec GPS réel. '
              'Les autres sont positionnées au chef-lieu départemental '
              '(approximation, exclues du calcul de distance).',
              style: TextStyle(
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
                style: TextStyle(
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
            style: TextStyle(fontSize: 8, color: kTextMuted)),
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
                          style: TextStyle(
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
                      style: TextStyle(
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
      Row(children: [
        Icon(Icons.layers_rounded, size: 13, color: kGreen),
        const SizedBox(width: 6),
        Text('COUCHES DISPONIBLES',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 1.0)),
      ]),
      const SizedBox(height: 6),
      ...available.map((i) => tile(i.$1, i.$2, i.$3, i.$4, i.$5)),

      const SizedBox(height: 10),
      Divider(color: kBorder),
      const SizedBox(height: 10),

      // ── Couches manquantes ───────────────────────────────────────────────────
      Row(children: [
        Icon(Icons.layers_clear_rounded, size: 13, color: kRed),
        const SizedBox(width: 6),
        Text('COUCHES MANQUANTES',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 1.0)),
      ]),
      const SizedBox(height: 4),
      Text(
        'Données d\'institutions nationales — non présentes en base. '
        'Aucune n\'est simulée (« ne rien inventer »).',
        style: TextStyle(fontSize: 9, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 8),
      ...missing.map((i) => tile(i.$1, i.$2, i.$3, i.$4, i.$5)),
    ]);
  }
}

