part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANALYSES — ventilation département / type d'établissement.
//
//  L'évolution pluriannuelle vit dans `admin_year_evolution.dart`.
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
        // 720 et non 820 : à 150 % d'agrandissement Windows, la colonne de
        // contenu tombe sous 800 px logiques et les deux cartes s'empilaient —
        // un anneau de 230 px seul au milieu d'une carte large de huit cents.
        final wide = c.maxWidth >= 720;
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

// ════════════════════════════════════════════════════════════════════════════
//  RÉPARTITION PAR DÉPARTEMENT
//
//  ⚠️ LA COULEUR DOIT DIRE QUELQUE CHOSE, SINON ELLE MENT.
//  Les barres portaient une couleur différente chacune, tirée d'une palette
//  arc-en-ciel de dix teintes. Le rose de « Pool » et le violet de « Sangha »
//  n'encodaient rien : ni le rang, ni le volume, ni le statut. L'œil y cherche
//  pourtant une catégorie — c'est ainsi qu'il lit une couleur — et n'en trouve
//  aucune. Une seule teinte, dégradée du plus fort au plus faible, rend la
//  hiérarchie lisible AVANT la lecture des chiffres.
//
//  Le rail gris derrière chaque barre (`isTrackVisible`) donne l'échelle sans
//  qu'aucun axe n'ait à l'écrire : la barre la plus longue remplit son rail,
//  les autres se comparent à elle. L'axe numérique disparaît donc — ses
//  graduations dupliquaient les étiquettes de valeur posées en bout de barre.
// ════════════════════════════════════════════════════════════════════════════

/// Dégradé d'intensité : le premier département (le plus gros) est plein, le
/// dernier à 45 %. Une seule teinte, huit rangs lisibles.
Color _rampeDept(int i, int n) {
  final t = n <= 1 ? 0.0 : i / (n - 1);
  // Plancher à 55 % : en dessous, la barre la plus courte devenait si pâle
  // qu'elle se confondait avec son rail — un département présent se lisait
  // comme un département vide.
  return kNavy.withValues(alpha: 1 - 0.45 * t);
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
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead('Répartition par département',
              icon: Icons.map_rounded,
              tint: const Color(0xFF7C3AED),
              subtitle: caches > 0
                  ? 'Les $_kMaxBarres premiers sur ${tous.length} — '
                      'cliquez une barre pour le détail'
                  : 'Élèves inscrits par département — '
                      'cliquez une barre pour le détail'),
          const SizedBox(height: 16),
          SizedBox(
            // 34 px par barre : au-dessus, huit départements laissaient de
            // larges vides ; en dessous, les étiquettes se touchaient.
            height: (data.length * 34.0).clamp(150.0, 300.0),
            child: loading
                ? Center(child: CircularProgressIndicator(color: kNavy))
                : enErreur
                    ? _ChartError(
                        quoi: 'la répartition par département',
                        onRetry: onRetry)
                    : !hasData
                        ? const _ChartEmpty(
                            message: 'Aucun élève inscrit sur cette année.')
                        : _barres(context, data),
          ),
          if (caches > 0) ...[
            const SizedBox(height: 12),
            _NoteGraphe(
              icon: Icons.more_horiz_rounded,
              color: kTextMuted,
              message: '$caches département${caches > 1 ? 's' : ''} de plus, '
                  'hors du graphe — la table « Préparation par école » les '
                  'porte tous.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _barres(BuildContext context, List<YearDeptStat> data) {
    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: kNavyDark,
        borderWidth: 0,
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
        format: 'point.x : point.y élèves',
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: kTextPrimary,
        ),
      ),
      // L'axe des valeurs est MUET : le rail donne l'échelle, l'étiquette en
      // bout de barre donne le chiffre. Deux fois la même information sur un
      // graphe de huit lignes, c'est une de trop.
      primaryYAxis: const NumericAxis(minimum: 0, isVisible: false),
      series: <CartesianSeries<YearDeptStat, String>>[
        BarSeries<YearDeptStat, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.department,
          yValueMapper: (d, _) => d.eleves,
          pointColorMapper: (d, i) => _rampeDept(i, data.length),
          width: 0.58,
          spacing: 0.15,
          animationDuration: 900,
          borderRadius: BorderRadius.circular(7),
          isTrackVisible: true,
          trackColor: kSurface,
          trackBorderWidth: 0,
          selectionBehavior: SelectionBehavior(
            enable: true,
            selectedOpacity: 1,
            unselectedOpacity: 0.28,
          ),
          // La barre mène au même endroit que la ligne de la table : le
          // département, ses établissements, sa fiche. Deux chemins, une
          // seule destination.
          onPointTap: (details) {
            final i = details.pointIndex;
            final a = analytics;
            if (i == null || a == null || i >= data.length) return;
            showYearDepartmentSheet(
              context,
              year: year,
              analytics: a,
              department: data[i].department,
            );
          },
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barres affichées par le graphe départemental. Au-delà, les libellés se
/// chevauchent et le graphe cesse d'être lisible ; le nombre exclu est écrit
/// sous le graphe plutôt que passé sous silence.
const int _kMaxBarres = 8;

// ════════════════════════════════════════════════════════════════════════════
//  TYPE D'ÉTABLISSEMENT — anneau fin, extrémités arrondies, total au centre.
//
//  L'anneau précédent était un beignet épais d'un seul bleu plat qui occupait
//  toute la carte pour dire « 100 % public ». Il est aminci, ses extrémités
//  arrondies (sauf sur un anneau plein, où deux arrondis qui se rejoignent
//  produisent une encoche), et la légende porte désormais la PART de chaque
//  statut — c'est ce qu'on vient chercher dans un anneau.
// ════════════════════════════════════════════════════════════════════════════
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
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead("Type d'établissement",
              icon: Icons.account_balance_rounded,
              tint: kAccent,
              subtitle: 'Part des effectifs par statut'),
          const SizedBox(height: 8),
          SizedBox(
            height: 216,
            child: loading
                ? Center(child: CircularProgressIndicator(color: kNavy))
                : enErreur
                    ? _ChartError(
                        quoi: "la ventilation par type d'établissement",
                        onRetry: onRetry)
                    : total == 0
                        ? const _ChartEmpty(message: 'Aucune donnée.')
                        : _anneau(data, total),
          ),
          const SizedBox(height: 10),
          ...data.map((t) => _LigneType(stat: t, total: total)),
        ],
      ),
    );
  }

  Widget _anneau(List<YearTypeStat> data, int total) {
    return SfCircularChart(
      margin: EdgeInsets.zero,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: kNavyDark,
        borderWidth: 0,
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      annotations: <CircularChartAnnotation>[
        CircularChartAnnotation(
          widget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmtInt(total),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: kTextPrimary)),
              Text('élèves',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted)),
              const SizedBox(height: 4),
              Text(
                '${data.length} statut${data.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10.5, color: kTextMuted),
              ),
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
          radius: '86%',
          innerRadius: '76%',
          // Deux arrondis qui se rejoignent sur un anneau plein créent une
          // encoche : on ne les demande qu'à partir de deux secteurs.
          cornerStyle:
              data.length > 1 ? CornerStyle.bothCurve : CornerStyle.bothFlat,
          strokeColor: kCardBg,
          strokeWidth: 2,
          animationDuration: 900,
          selectionBehavior: SelectionBehavior(
            enable: true,
            selectedOpacity: 1,
            unselectedOpacity: 0.35,
          ),
        ),
      ],
    );
  }
}

/// Une ligne de légende : pastille, libellé, part, et le détail à droite.
class _LigneType extends StatelessWidget {
  const _LigneType({required this.stat, required this.total});
  final YearTypeStat stat;
  final int total;

  @override
  Widget build(BuildContext context) {
    final couleur = _typeColor(stat.type);
    final part = total == 0 ? 0.0 : stat.eleves / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: couleur, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_typeLabel(stat.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              Text('${(part * 100).round()} %',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: couleur)),
            ],
          ),
          const SizedBox(height: 5),
          // La jauge occupe TOUTE la ligne. Partagée avec le détail chiffré,
          // elle ne faisait qu'un dixième de la carte : une part de 100 % s'y
          // lisait comme une part minoritaire.
          AdminProgressBar(value: part, max: 1, height: 5, color: couleur),
          const SizedBox(height: 4),
          Text(
              '${fmtInt(stat.eleves)} élèves · ${stat.ecoles} écoles · '
              '${stat.classes} classes',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ],
      ),
    );
  }
}
