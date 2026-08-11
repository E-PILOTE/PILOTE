part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANALYSES — évolution pluriannuelle, ventilation département / type, écoles.
// ════════════════════════════════════════════════════════════════════════════

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 38, color: kTextMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  UN ÉCHEC DE CHARGEMENT N'EST PAS UN ENSEMBLE VIDE.
//
//  Toutes les cartes de cette page lisaient `valueOrNull` et, quand il valait
//  `null` sans être en cours de chargement, affichaient « Aucune école active
//  dans le groupe », « Aucun élève inscrit sur cette année », « Aucun trimestre
//  défini ». Or `null` recouvre deux situations opposées : il n'y a rien, ou on
//  n'a pas pu savoir.
//
//  Une RPC en échec — réseau congolais coupé, `statement_timeout = 8 s` du rôle
//  `authenticator`, jeton expiré — annonçait donc au ministère que son réseau
//  était vide, avec l'aplomb d'un chiffre. Et rien ne permettait de réessayer
//  sans quitter la page.
// ════════════════════════════════════════════════════════════════════════════
class _ChartError extends StatelessWidget {
  const _ChartError({required this.quoi, required this.onRetry});

  /// Ce qui n'a pas pu être chargé, à la suite de « Impossible de charger ».
  final String quoi;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 34, color: kRed.withValues(alpha: 0.55)),
              const SizedBox(height: 10),
              Text('Impossible de charger $quoi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Ces chiffres sont INCONNUS, pas nuls. '
                  'Vérifiez la connexion, puis réessayez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réessayer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Évolution pluriannuelle (élèves + classes) ────────────────────────────────
class _EvoPoint {
  const _EvoPoint(this.label, this.eleves, this.classes);
  final String label;
  final int eleves, classes;
}

class _EvolutionCard extends StatefulWidget {
  const _EvolutionCard({required this.years});
  final List<AdminYear> years;
  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, shared: true);

  @override
  Widget build(BuildContext context) {
    // Ordre chronologique (la liste source est triée DESC).
    final pts = widget.years.reversed
        .map((y) => _EvoPoint(y.label, y.eleves, y.classes))
        .toList();
    final hasData = pts.any((p) => p.eleves > 0 || p.classes > 0);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Évolution des effectifs',
              icon: Icons.show_chart_rounded,
              subtitle: 'Élèves inscrits et classes ouvertes par année scolaire'),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: !hasData
                ? const _ChartEmpty(
                    message: 'Les effectifs apparaîtront dès la préparation '
                        'des classes par les écoles.')
                : SfCartesianChart(
                    backgroundColor: Colors.transparent,
                    plotAreaBorderWidth: 0,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.top,
                      overflowMode: LegendItemOverflowMode.wrap,
                      textStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: 0,
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      majorGridLines: MajorGridLines(
                        width: 1,
                        color: kBorder.withValues(alpha: 0.7),
                        dashArray: const <double>[4, 4],
                      ),
                      labelStyle:
                          TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    axes: <ChartAxis>[
                      NumericAxis(
                        name: 'yClasses',
                        opposedPosition: true,
                        minimum: 0,
                        axisLine: const AxisLine(width: 0),
                        majorTickLines: const MajorTickLines(size: 0),
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
                      ),
                    ],
                    series: <CartesianSeries<_EvoPoint, String>>[
                      SplineAreaSeries<_EvoPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.eleves,
                        name: 'Élèves',
                        animationDuration: 1000,
                        splineType: SplineType.natural,
                        borderColor: kGreen,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            kGreen.withValues(alpha: 0.26),
                            kGreen.withValues(alpha: 0.02),
                          ],
                        ),
                        markerSettings: MarkerSettings(
                            isVisible: true,
                            height: 6,
                            width: 6,
                            color: kGreen),
                      ),
                      ColumnSeries<_EvoPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.classes,
                        name: 'Classes',
                        yAxisName: 'yClasses',
                        width: 0.32,
                        animationDuration: 1000,
                        color: kNavy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Ligne : département (barres) + type d'établissement (donut) ───────────────
class _AnalyticsRow extends ConsumerWidget {
  const _AnalyticsRow({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearAnalyticsProvider(year.id));
    final a = async.valueOrNull;
    void recharger() => ref.invalidate(adminYearAnalyticsProvider(year.id));

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final dept = _DepartmentChart(
            year: year,
            analytics: a,
            loading: async.isLoading,
            enErreur: async.hasError,
            onRetry: recharger);
        final type = _TypeDonut(
            analytics: a,
            loading: async.isLoading,
            enErreur: async.hasError,
            onRetry: recharger);
        if (wide) {
          // ⚠️ Pas de CrossAxisAlignment.stretch ici : la Row est dans un
          // ListView (hauteur non bornée) → stretch force h=∞ et casse le rendu.
          // Les cartes s'auto-dimensionnent (alignées en haut) — Syncfusion ne
          // supporte pas les intrinsèques, donc IntrinsicHeight est exclu.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: dept),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: type),
            ],
          );
        }
        return Column(children: [dept, const SizedBox(height: 16), type]);
      },
    );
  }
}

class _DepartmentChart extends StatelessWidget {
  const _DepartmentChart({
    required this.year,
    required this.analytics,
    required this.loading,
    required this.enErreur,
    required this.onRetry,
  });
  final AdminYear year;
  final AdminYearAnalytics? analytics;
  final bool loading;
  final bool enErreur;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tous = analytics?.byDepartment ?? const <YearDeptStat>[];
    final data = tous.take(_kMaxBarres).toList();
    final hasData = data.any((d) => d.eleves > 0);
    // Le graphe n'affiche que les huit premiers départements. Tant que le
    // titre annonce « répartition par département » sans dire lesquels, un
    // douzième département invisible se lit comme un département inexistant.
    final caches = tous.length - data.length;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle('Répartition par département',
              icon: Icons.map_rounded,
              subtitle: caches > 0
                  ? 'Les $_kMaxBarres premiers sur ${tous.length} — '
                      'cliquez une barre pour le détail'
                  : 'Élèves inscrits par département — '
                      'cliquez une barre pour le détail'),
          const SizedBox(height: 14),
          SizedBox(
            height: 270,
            child: loading
                ? Center(child: CircularProgressIndicator(color: kNavy))
                : enErreur
                    ? _ChartError(
                        quoi: 'la répartition par département',
                        onRetry: onRetry)
                    : !hasData
                    ? const _ChartEmpty(
                        message: 'Aucun élève inscrit sur cette année.')
                    : SfCartesianChart(
                        backgroundColor: Colors.transparent,
                        plotAreaBorderWidth: 0,
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(
                            enable: true, format: 'point.x : point.y élèves'),
                        primaryXAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          labelStyle:
                              TextStyle(fontSize: 11, color: kTextPrimary),
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          majorGridLines: MajorGridLines(
                            width: 1,
                            color: kBorder.withValues(alpha: 0.7),
                            dashArray: const <double>[4, 4],
                          ),
                          labelStyle:
                              TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                        series: <CartesianSeries<YearDeptStat, String>>[
                          BarSeries<YearDeptStat, String>(
                            dataSource: data,
                            xValueMapper: (d, _) => d.department,
                            yValueMapper: (d, _) => d.eleves,
                            pointColorMapper: (d, i) => _palAt(i),
                            width: 0.66,
                            spacing: 0.2,
                            animationDuration: 900,
                            borderRadius: BorderRadius.circular(5),
                            // La barre mène au même endroit que la ligne de la
                            // table : le département, ses établissements, sa
                            // fiche. Deux chemins, une seule destination.
                            onPointTap: (details) {
                              final i = details.pointIndex;
                              final a = analytics;
                              if (i == null || a == null || i >= data.length) {
                                return;
                              }
                              showYearDepartmentSheet(
                                context,
                                year: year,
                                analytics: a,
                                department: data[i].department,
                              );
                            },
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kTextMuted),
                            ),
                          ),
                        ],
                      ),
          ),
          if (caches > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.more_horiz_rounded, size: 15, color: kTextMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$caches département${caches > 1 ? 's' : ''} de plus, '
                  'hors du graphe — la table « Préparation par école » les '
                  'porte tous.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Barres affichées par le graphe départemental. Au-delà, les libellés se
/// chevauchent et le graphe cesse d'être lisible ; le nombre exclu est écrit
/// sous le graphe plutôt que passé sous silence.
const int _kMaxBarres = 8;

class _TypeDonut extends StatelessWidget {
  const _TypeDonut({
    required this.analytics,
    required this.loading,
    required this.enErreur,
    required this.onRetry,
  });
  final AdminYearAnalytics? analytics;
  final bool loading;
  final bool enErreur;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = (analytics?.byType ?? const <YearTypeStat>[])
        .where((t) => t.eleves > 0)
        .toList();
    final total = data.fold<int>(0, (a, t) => a + t.eleves);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle("Type d'établissement",
              icon: Icons.account_balance_rounded,
              subtitle: 'Élèves par statut'),
          const SizedBox(height: 6),
          SizedBox(
            height: 230,
            child: loading
                ? Center(child: CircularProgressIndicator(color: kNavy))
                : enErreur
                    ? _ChartError(
                        quoi: "la ventilation par type d'établissement",
                        onRetry: onRetry)
                    : total == 0
                    ? const _ChartEmpty(message: 'Aucune donnée.')
                    : SfCircularChart(
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(enable: true),
                        annotations: <CircularChartAnnotation>[
                          CircularChartAnnotation(
                            widget: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$total',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: kTextPrimary)),
                                Text('élèves',
                                    style: TextStyle(
                                        fontSize: 11, color: kTextMuted)),
                              ],
                            ),
                          ),
                        ],
                        series: <CircularSeries<YearTypeStat, String>>[
                          DoughnutSeries<YearTypeStat, String>(
                            dataSource: data,
                            xValueMapper: (t, _) => _typeLabel(t.type),
                            yValueMapper: (t, _) => t.eleves,
                            pointColorMapper: (t, _) => _typeColor(t.type),
                            innerRadius: '66%',
                            animationDuration: 900,
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 8),
          ...data.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _typeColor(t.type),
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_typeLabel(t.type),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                    Text('${t.ecoles} écoles · ${t.classes} cl.',
                        style:
                            TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// La table « Préparation par école » vit désormais dans
// `admin_year_adoption.dart` : tri, recherche, virtualisation et relance des
// retardataires ne relevaient plus du simple graphique.
