part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PIPELINE PAR CYCLE / NIVEAU / CLASSE — lentille « admissions en cours »
//  (dossiers non encore validés). Bascule la dimension ; à gauche le poids par
//  catégorie, à droite l'évolution (arrivées par mois, empilées par catégorie).
//  Distinct de la page Élèves (effectif VALIDÉ) → zéro doublon.
// ════════════════════════════════════════════════════════════════════════════

// Palette de séries (niveaux/classes — plusieurs par cycle, couleurs distinctes).
const _seriesPalette = <Color>[
  kNavy,
  kGreen,
  _kBlue,
  _kPink,
  kAccent,
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
  Color(0xFFB45309),
];

class _PipelineCard extends ConsumerStatefulWidget {
  const _PipelineCard();
  @override
  ConsumerState<_PipelineCard> createState() => _PipelineCardState();
}

class _PipelineCardState extends ConsumerState<_PipelineCard> {
  String _dim = 'cycle'; // cycle | niveau | classe

  String get _dimLabel => switch (_dim) {
        'niveau' => 'niveau',
        'classe' => 'classe',
        _ => 'cycle',
      };

  Color _catColor(PipelineCat c, int idx) => _dim == 'cycle'
      ? _cycleColor(c.cycleCode)
      : _seriesPalette[idx % _seriesPalette.length];

  @override
  Widget build(BuildContext context) {
    final evo = ref.watch(pipelineEvolutionProvider(_dim));
    final cats = evo.cats;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insights_rounded, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Pipeline par $_dimLabel',
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          _DimToggle(
            value: _dim,
            onChanged: (v) => setState(() => _dim = v),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
              'Dossiers en cours de traitement (hors validés) · répartition et arrivées par mois',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        const SizedBox(height: 14),
        if (cats.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(children: [
              Icon(Icons.task_alt_rounded, size: 18, color: kGreen),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Aucun dossier en cours pour cette dimension. Les inscriptions '
                    'validées figurent dans la page Élèves.',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted)),
              ),
            ]),
          )
        else
          LayoutBuilder(builder: (ctx, c) {
            final bars = _PipelineBars(
                cats: cats, total: evo.grandTotal, colorOf: _catColor);
            final chart = _PipelineChart(
                evo: evo, dim: _dim, colorOf: _catColor);
            if (c.maxWidth >= 880) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: bars),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: chart),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [bars, const SizedBox(height: 18), chart],
            );
          }),
      ]),
    );
  }
}

// ─── Compteurs par catégorie (barres horizontales) ───────────────────────────
class _PipelineBars extends StatelessWidget {
  const _PipelineBars(
      {required this.cats, required this.total, required this.colorOf});
  final List<PipelineCat> cats;
  final int total;
  final Color Function(PipelineCat, int) colorOf;

  @override
  Widget build(BuildContext context) {
    final maxN = cats.fold<int>(0, (m, e) => e.total > m ? e.total : m);
    const cap = 12;
    final shown = cats.length > cap ? cats.sublist(0, cap) : cats;
    final hidden = cats.length - shown.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$total',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(width: 6),
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text('dossier(s) en cours',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ),
      ]),
      const SizedBox(height: 10),
      for (var i = 0; i < shown.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            SizedBox(
              width: 92,
              child: Text(shown[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxN == 0 ? 0 : (shown[i].total / maxN).clamp(0.02, 1.0),
                  minHeight: 15,
                  backgroundColor: kSurface,
                  valueColor: AlwaysStoppedAnimation(
                      colorOf(shown[i], i).withValues(alpha: 0.85)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                  '${shown[i].total}'
                  '${total > 0 ? ' · ${(shown[i].total * 100 / total).round()}%' : ''}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
            ),
          ]),
        ),
      if (hidden > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('+ $hidden autre(s)',
              style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
    ]);
  }
}

// ─── Évolution empilée par catégorie ─────────────────────────────────────────
class _PipelineChart extends StatelessWidget {
  const _PipelineChart(
      {required this.evo, required this.dim, required this.colorOf});
  final PipelineEvolution evo;
  final String dim;
  final Color Function(PipelineCat, int) colorOf;

  @override
  Widget build(BuildContext context) {
    final months = evo.months;
    if (months.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text('Dates d\'inscription non renseignées.',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ),
      );
    }
    // Cap des séries empilées (au-delà → « Autres » fusionné).
    final cats = evo.cats;
    const cap = 7;
    final List<PipelineCat> series;
    if (cats.length > cap) {
      final top = cats.sublist(0, cap);
      final rest = cats.sublist(cap);
      final merged = List<int>.filled(months.length, 0);
      for (final r in rest) {
        for (var i = 0; i < months.length; i++) {
          merged[i] += r.monthly[i];
        }
      }
      final restTotal = rest.fold<int>(0, (s, e) => s + e.total);
      series = [
        ...top,
        PipelineCat('__autres__', 'Autres', 'autre', 9999, restTotal, merged),
      ];
    } else {
      series = cats;
    }
    final idx = List<int>.generate(months.length, (i) => i);

    return SizedBox(
      height: 250,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
        ),
        primaryXAxis: const CategoryAxis(
          majorGridLines: MajorGridLines(width: 0),
          labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        ),
        primaryYAxis: const NumericAxis(
          axisLine: AxisLine(width: 0),
          majorTickLines: MajorTickLines(size: 0),
          labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<int, String>>[
          for (var s = 0; s < series.length; s++)
            StackedColumnSeries<int, String>(
              name: series[s].label,
              dataSource: idx,
              xValueMapper: (i, _) => months[i],
              yValueMapper: (i, _) => series[s].monthly[i],
              color: series[s].key == '__autres__'
                  ? kTextMuted
                  : colorOf(series[s], s),
              width: 0.6,
            ),
        ],
      ),
    );
  }
}

// ─── Bascule de dimension ────────────────────────────────────────────────────
class _DimToggle extends StatelessWidget {
  const _DimToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('cycle', 'Cycle'),
        seg('niveau', 'Niveau'),
        seg('classe', 'Classe'),
      ]),
    );
  }
}
