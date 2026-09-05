part of '../super_dashboard_screen.dart';

// Cartouches, compteurs animés.

class _KD {
  _KD({
    required this.icon,
    required this.color,
    required this.rawValue,
    required this.format,
    required this.label,
    required this.trend,
    required this.trendUp,
    this.sub,
    this.sparkType = _SparkType.splineArea,
    this.pts        = const [],
    this.barsData   = const [],
    this.progressMax = 100.0,
    this.inconnu = false,
  });
  final IconData                    icon;
  final Color                       color;
  final double                      rawValue;
  final String Function(double)     format;
  final String                      label;
  final String                      trend;
  final bool                        trendUp;
  final String?                     sub;
  final _SparkType                  sparkType;
  final List<MonthlyPoint>          pts;
  final List<MapEntry<String, int>> barsData;
  final double                      progressMax;

  /// La mesure n'a PAS pu être lue. La carte affiche « — », pas un zéro : sur
  /// cet écran, zéro se lit comme un fait — « aucun élève », « aucun revenu ».
  final bool                        inconnu;
}

bool _hasSpark(_KD d) {
  switch (d.sparkType) {
    case _SparkType.spline:
    case _SparkType.splineArea:
    case _SparkType.column:
      return d.pts.length >= 2;
    case _SparkType.barH:
      return d.barsData.isNotEmpty;
    case _SparkType.progress:
      return true;
  }
}

Widget _buildSparkline(_KD d, int idx) {
  final delay = 420 + 70 * idx;
  switch (d.sparkType) {
    case _SparkType.spline:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.splineArea:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.column:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.barH:
      return _SparkBarH(data: d.barsData, color: d.color, delayMs: delay);
    case _SparkType.progress:
      return _SparkProgress(
          value: d.rawValue, max: d.progressMax,
          color: d.color, delayMs: delay);
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.isSyncing});
  final SuperDashboardData stats;
  final bool               isSyncing;

  @override
  Widget build(BuildContext context) {
    final items = [
      // 1 · Groupes actifs — SplineSeries (ligne fine, tendance mensuelle)
      _KD(
        icon: Icons.school_rounded, color: _kNavy,
        rawValue: stats.groupesActifs.toDouble(),
        format: (v) => _fmt(v.round()),
        inconnu: stats.indisponible(MesuresDashboard.ecolesEtGroupes),
        label: 'Groupes actifs',
        sub: '${stats.groupesTotal} au total',
        trend: _newThisMonth(stats.trendGroupes, 'groupe'),
        trendUp: _lastMonth(stats.trendGroupes) > 0,
        sparkType: _SparkType.spline,
        pts: stats.trendGroupes,
      ),
      // 2 · Écoles actives — ColumnSeries (colonnes verticales par mois)
      _KD(
        icon: Icons.domain_rounded, color: _kTeal,
        rawValue: stats.ecolesTotal.toDouble(),
        format: (v) => _fmt(v.round()),
        inconnu: stats.indisponible(MesuresDashboard.ecolesEtGroupes),
        label: 'Écoles actives',
        trend: _newThisMonth(stats.trendEcoles, 'école'),
        trendUp: _lastMonth(stats.trendEcoles) > 0,
        sparkType: _SparkType.column,
        pts: stats.trendEcoles,
      ),
      // 3 · Élèves total — SplineAreaSeries (zone remplie, volume)
      _KD(
        icon: Icons.people_alt_rounded, color: _kBlue,
        rawValue: stats.elevesTotal.toDouble(),
        format: (v) => _fmtLg(v.round()),
        inconnu: stats.indisponible(MesuresDashboard.eleves),
        label: 'Élèves total',
        trend: _newThisMonth(stats.trendEleves, 'inscrit'),
        trendUp: _lastMonth(stats.trendEleves) > 0,
        sparkType: _SparkType.splineArea,
        pts: stats.trendEleves,
      ),
      // 4 · Personnel — BarH (barres horizontales par rôle)
      //
      // Pas de série mensuelle pour le personnel : la carte affichait « ↑ +8 % »,
      // un pourcentage précis que rien ne calculait. On dit ce qu'on sait —
      // combien de métiers différents composent ce total.
      _KD(
        icon: Icons.badge_rounded, color: _kPurple,
        rawValue: stats.personnelTotal.toDouble(),
        format: (v) => _fmt(v.round()),
        inconnu: stats.indisponible(MesuresDashboard.personnel),
        label: 'Personnel actif',
        trend: stats.personnelByRole.isEmpty
            ? '—'
            : '${stats.personnelByRole.length} métier'
                '${stats.personnelByRole.length > 1 ? 's' : ''}',
        trendUp: stats.personnelTotal > 0,
        sparkType: _SparkType.barH,
        barsData: stats.personnelByRole,
      ),
      // 5 · Revenus — SplineAreaSeries dégradé gold (masse financière)
      _KD(
        icon: Icons.account_balance_rounded, color: _kGold,
        rawValue: stats.revenusXafMois,
        format: (v) => _fmtRevenu(v),
        inconnu: stats.indisponible(MesuresDashboard.ecolesEtGroupes),
        label: 'Revenus XAF/mois',
        sub: 'FCFA · abonnements actifs',
        trend: _lastMonth(stats.trendRevenus) > 0
            ? '${_fmtRevenu(_lastMonth(stats.trendRevenus))} encaissés'
            : 'aucun encaissement ce mois',
        trendUp: _lastMonth(stats.trendRevenus) > 0,
        sparkType: _SparkType.splineArea,
        pts: stats.trendRevenus,
      ),
      // 6 · Abonnements — BarH (barres horizontales par statut)
      _KD(
        icon: Icons.verified_rounded, color: _kGreen,
        rawValue: stats.abonnementsActifs.toDouble(),
        format: (v) => _fmt(v.round()),
        inconnu: stats.indisponible(MesuresDashboard.ecolesEtGroupes),
        label: 'Abonnements actifs',
        trend: stats.expirantDans30j > 0
            ? '⚠ ${stats.expirantDans30j} expirent' : '✅ À jour',
        trendUp: stats.expirantDans30j == 0,
        sparkType: _SparkType.barH,
        barsData: stats.abonnementsByStatus,
      ),
      // 7 · Écoles géolocalisées — barre de progression
      //
      // ⚠️ Remplace « Sync réussie 99,7 % », qui était une CONSTANTE. Rien dans
      // la plateforme ne mesure un taux de synchronisation : le chiffre
      // s'affichait identique, base pleine ou base vide, application en ligne
      // ou hors ligne. Ce qui suit se compte : combien d'écoles portent des
      // coordonnées, donc apparaissent réellement sur la carte nationale.
      _KD(
        icon: Icons.place_rounded, color: _kBlue,
        rawValue: stats.ecolesTotal == 0
            ? 0
            : stats.ecolesGeolocalisees * 100 / stats.ecolesTotal,
        format: (v) => '${v.toStringAsFixed(0)}%',
        label: 'Écoles géolocalisées',
        sub: '${stats.ecolesGeolocalisees}/${stats.ecolesTotal} sur la carte',
        trend: isSyncing ? '✅ En ligne' : '⚡ Hors ligne',
        trendUp: isSyncing,
        sparkType: _SparkType.progress,
        progressMax: 100.0,
      ),
      // 8 · Couverture territoriale — barre de progression
      //
      // ⚠️ Remplace « Disponibilité SLA 99,5 % », constante elle aussi : un
      // engagement de service annoncé à un ministère sans rien pour le mesurer.
      _KD(
        icon: Icons.map_rounded, color: _kTeal,
        rawValue: stats.departementsTotal == 0
            ? 0
            : stats.departementsCouverts * 100 / stats.departementsTotal,
        format: (v) => '${v.toStringAsFixed(0)}%',
        label: 'Couverture nationale',
        sub: '${stats.departementsCouverts}/${stats.departementsTotal} '
            'départements',
        trend: stats.departementsCouverts == 0
            ? 'aucun département'
            : '${stats.departementsCouverts} atteint'
                '${stats.departementsCouverts > 1 ? 's' : ''}',
        trendUp: stats.departementsCouverts > 0,
        sparkType: _SparkType.progress,
        progressMax: 100.0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final w    = c.maxWidth;
      final cols = w > 900 ? 4 : w > 600 ? 3 : 2;
      final gaps = (cols - 1) * 14.0;
      final ratio = ((w - gaps) / cols / 150.0).clamp(1.0, 4.0);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: ratio,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

// ─── Carte KPI premium ────────────────────────────────────────────────────────
class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}
class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 70 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }
  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d     = widget.d;
    final spark = _hasSpark(d);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hov
                    ? d.color.withValues(alpha: 0.42)
                    : d.color.withValues(alpha: 0.14),
                width: 1.3,
              ),
              boxShadow: [BoxShadow(
                color: _hov
                    ? d.color.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.07),
                blurRadius: _hov ? 24 : 14,
                offset: Offset(0, _hov ? 8 : 4),
                spreadRadius: _hov ? 0 : -1,
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bande accent colorée
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        d.color,
                        d.color.withValues(alpha: _hov ? 0.95 : 0.45),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icône + libellé + badge tendance
                          Row(children: [
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: d.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(d.icon, size: 14, color: d.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d.label,
                                style: TextStyle(color: _kMuted,
                                    fontSize: 10.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (d.trendUp ? _kGreen : _kOrange)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(d.trend, style: TextStyle(
                                  color: d.trendUp ? _kGreen : _kOrange,
                                  fontSize: 8.5, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 7),
                          // Nombre animé — ou « — » quand la mesure a échoué :
                          // un compteur qui monte jusqu'à zéro affirmerait un
                          // fait que personne n'a mesuré.
                          if (d.inconnu)
                            Text('—', style: TextStyle(
                              color: _kText.withValues(alpha: 0.45),
                              fontSize: 25, fontWeight: FontWeight.w900,
                              letterSpacing: -0.6, height: 1.0,
                            ))
                          else
                            _CountUp(
                              target: d.rawValue,
                              format: d.format,
                              delayMs: 300 + 70 * widget.idx,
                              style: TextStyle(
                                color: _kText, fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6, height: 1.0,
                                shadows: [Shadow(
                                    color: d.color.withValues(alpha: 0.15),
                                    blurRadius: 8)],
                              ),
                            ),
                          if (d.sub != null) ...[
                            const SizedBox(height: 2),
                            Text(d.sub!, style: TextStyle(
                                color: d.color.withValues(alpha: 0.75),
                                fontSize: 9.5, fontWeight: FontWeight.w500)),
                          ],
                          const Spacer(),
                          if (spark) _buildSparkline(d, widget.idx),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CountUp animé ────────────────────────────────────────────────────────────
class _CountUp extends StatefulWidget {
  const _CountUp({
    required this.target, required this.format,
    required this.style, this.delayMs = 300,
  });
  final double target; final String Function(double) format;
  final TextStyle style; final int delayMs;
  @override
  State<_CountUp> createState() => _CountUpState();
}
class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Text(
        widget.format(widget.target * _anim.value), style: widget.style),
  );
}

// ─── Sparkline A : Syncfusion (spline / splineArea / column) ─────────────────
