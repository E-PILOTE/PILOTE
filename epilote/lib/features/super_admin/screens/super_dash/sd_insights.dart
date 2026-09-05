part of '../super_dashboard_screen.dart';

// Panneau d’analyses automatiques.

enum _InsightType { positive, warning, critical, info, forecast }

class _Insight {
  const _Insight({required this.icon, required this.title,
      required this.detail, required this.type});
  final String      icon;
  final String      title;
  final String      detail;
  final _InsightType type;
}

Color _insightColor(_InsightType t) => switch (t) {
  _InsightType.positive => const Color(0xFF34D399),
  _InsightType.warning  => const Color(0xFFFBBF24),
  _InsightType.critical => const Color(0xFFF87171),
  _InsightType.forecast => const Color(0xFFA5B4FC),
  _InsightType.info     => Colors.white,
};

List<_Insight> _buildInsights(SuperDashboardData stats) {
  final list = <_Insight>[];

  // 1. Tendance revenus 3M vs 3M précédents
  if (stats.revenueMonthly.length >= 6) {
    final all   = stats.revenueMonthly;
    final last3 = all.sublist(all.length - 3).fold(0.0, (s, r) => s + r.amount);
    final prev3 = all.sublist(all.length - 6, all.length - 3)
        .fold(0.0, (s, r) => s + r.amount);
    if (prev3 > 0) {
      final pct = (last3 - prev3) / prev3 * 100;
      list.add(_Insight(
        icon: pct >= 0 ? '📈' : '📉',
        title: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% de revenus ce trimestre',
        detail: '${_fmtRevenuFull(last3)} vs ${_fmtRevenuFull(prev3)} le trimestre précédent',
        type: pct >= 5 ? _InsightType.positive
            : pct >= 0 ? _InsightType.info : _InsightType.warning,
      ));
    }
  }

  // 2. Risque churn — abonnements expirants
  if (stats.expirantDans30j > 0) {
    final avgRev = stats.abonnementsActifs > 0
        ? stats.revenusXafMois / stats.abonnementsActifs : 0.0;
    final atRisk = avgRev * stats.expirantDans30j;
    list.add(_Insight(
      icon: '⚠️',
      title: '${stats.expirantDans30j} abonnement'
          '${stats.expirantDans30j > 1 ? 's' : ''} en danger',
      detail: '~${_fmtRevenuFull(atRisk)} de revenus à risque — contacter maintenant',
      type: stats.expirantDans30j >= 3 ? _InsightType.critical : _InsightType.warning,
    ));
  }

  // 3. Prévision revenus mois suivant
  if (stats.revenueMonthly.length >= 4) {
    final forecast = _forecastRevenue(stats.revenueMonthly);
    if (forecast > 0) {
      final delta = forecast - stats.revenusXafMois;
      list.add(_Insight(
        icon: '🔮',
        title: 'Prévision mois prochain : ${_fmtRevenuFull(forecast)}',
        detail: '${delta >= 0 ? '+' : ''}${_fmtRevenu(delta)} vs MRR actuel'
            ' (régression linéaire 6M)',
        type: _InsightType.forecast,
      ));
    }
  }

  // 4. Rythme de croissance groupes
  if (stats.trendGroupes.length >= 3) {
    final n = stats.trendGroupes.sublist(stats.trendGroupes.length - 3)
        .fold(0.0, (s, p) => s + p.value);
    if (n > 0) {
      list.add(_Insight(
        icon: '🚀',
        title: '${n.toInt()} nouveau${n > 1 ? 'x' : ''} groupe${n > 1 ? 's' : ''} ce trimestre',
        detail: 'rythme : ${(n / 3).toStringAsFixed(1)} groupe/mois — '
            '${stats.groupesActifs} actifs au total',
        type: _InsightType.positive,
      ));
    }
  }

  // 5. Concentration plan
  if (stats.groupesByPlan.isNotEmpty) {
    final top   = stats.groupesByPlan.first;
    final total = stats.groupesByPlan.fold(0, (s, e) => s + e.value);
    if (total > 0) {
      final pct = (top.value / total * 100).round();
      if (pct > 50) {
        list.add(_Insight(
          icon: '💡',
          title: 'Plan "${top.key}" : $pct% des groupes',
          detail: 'opportunité d\'upsell vers Premium ou Institutionnel',
          type: _InsightType.info,
        ));
      }
    }
  }

  // 6. Département dominant
  if (stats.deptStats.isNotEmpty && stats.groupesTotal > 0) {
    final top = stats.deptStats.first;
    final pct = (top.groupCount / stats.groupesTotal * 100).round();
    if (pct > 45) {
      list.add(_Insight(
        icon: '🗺️',
        title: '${top.dept} concentre $pct% des groupes',
        detail: 'fort potentiel d\'expansion dans les autres départements',
        type: _InsightType.info,
      ));
    }
  }

  // État vide — aucune donnée encore
  if (stats.groupesTotal == 0) {
    list.add(const _Insight(
      icon: '🏫',
      title: 'Aucun groupe enregistré',
      detail: 'Créez votre premier groupe scolaire pour démarrer l\'analyse',
      type: _InsightType.info,
    ));
  }
  if (stats.ecolesTotal == 0 && stats.groupesTotal > 0) {
    list.add(const _Insight(
      icon: '🏗️',
      title: 'Aucune école associée',
      detail: 'Ajoutez des écoles aux groupes pour enrichir les statistiques',
      type: _InsightType.info,
    ));
  }
  if (stats.revenusXafMois == 0 && stats.groupesTotal > 0) {
    list.add(const _Insight(
      icon: '💰',
      title: 'MRR à zéro',
      detail: 'Configurez des plans d\'abonnement avec un prix pour suivre les revenus',
      type: _InsightType.warning,
    ));
  }

  if (list.isEmpty) {
    list.add(const _Insight(
      icon: '✅',
      title: 'Plateforme en bonne santé',
      detail: 'Aucune anomalie détectée — continuez sur cette lancée',
      type: _InsightType.positive,
    ));
  }

  return list.take(5).toList();
}

double _forecastRevenue(List<MonthlyRevenue> months) {
  final n = months.length;
  if (n < 3) return 0;
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < n; i++) {
    sumX += i; sumY += months[i].amount;
    sumXY += i * months[i].amount; sumX2 += i * i;
  }
  final denom = n * sumX2 - sumX * sumX;
  if (denom == 0) return months.last.amount;
  final slope     = (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;
  return (intercept + slope * n).clamp(0, double.infinity);
}

class _AiInsightsPanel extends ConsumerStatefulWidget {
  const _AiInsightsPanel({required this.stats});
  final SuperDashboardData stats;
  @override
  ConsumerState<_AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends ConsumerState<_AiInsightsPanel>
    with SingleTickerProviderStateMixin {
  late DateTime          _analysedAt;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _analysedAt = DateTime.now();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AiInsightsPanel old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) _analysedAt = DateTime.now();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _refresh() {
    ref.invalidate(superDashboardProvider);
    setState(() => _analysedAt = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final stats    = widget.stats;
    final insights = _buildInsights(stats);
    final timeStr  = DateFormat('HH:mm:ss').format(_analysedAt);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
          blurRadius: 24, offset: const Offset(0, 8),
        )],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─ En-tête ─────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 19, color: Color(0xFFA5B4FC)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Insights IA', style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            Text('Analysé à $timeStr · Supabase live',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5)),
          ])),
          // Badge pulsant "Live"
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08 + _pulse.value * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF34D399)
                        .withValues(alpha: 0.35 + _pulse.value * 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399)
                          .withValues(alpha: 0.70 + _pulse.value * 0.30),
                      shape: BoxShape.circle,
                    )),
                const SizedBox(width: 5),
                const Text('Live', style: TextStyle(
                    color: Color(0xFF34D399), fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton refresh
          Tooltip(
            message: 'Relancer l\'analyse',
            child: InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 14),

        // ─ Mini-KPIs réels depuis Supabase ────────────────────────────────
        Wrap(spacing: 8, runSpacing: 6, children: [
          _LiveChip(Icons.school_rounded,
              '${stats.groupesActifs}/${stats.groupesTotal} groupes',
              const Color(0xFF818CF8)),
          _LiveChip(Icons.domain_rounded,
              '${stats.ecolesTotal} écoles',
              const Color(0xFF34D399)),
          _LiveChip(Icons.people_alt_rounded,
              '${_fmtLg(stats.elevesTotal)} élèves',
              const Color(0xFF60A5FA)),
          _LiveChip(Icons.account_balance_wallet_rounded,
              'MRR ${_fmtRevenu(stats.revenusXafMois)} FCFA',
              _kGold),
          _LiveChip(Icons.verified_rounded,
              '${stats.abonnementsActifs} abonnements',
              const Color(0xFF4ADE80)),
          if (stats.expirantDans30j > 0)
            _LiveChip(Icons.warning_amber_rounded,
                '${stats.expirantDans30j} expirent bientôt',
                const Color(0xFFFB923C)),
        ]),

        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
        const SizedBox(height: 14),

        // ─ Insights générés ────────────────────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          if (c.maxWidth > 700) {
            final left  = [for (int i = 0; i < insights.length; i += 2) insights[i]];
            final right = [for (int i = 1; i < insights.length; i += 2) insights[i]];
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: left.asMap().entries.map((e) =>
                  _InsightTile(insight: e.value, delay: e.key * 120)).toList())),
              const SizedBox(width: 20),
              Expanded(child: Column(children: right.asMap().entries.map((e) =>
                  _InsightTile(insight: e.value, delay: e.key * 120 + 60)).toList())),
            ]);
          }
          return Column(children: insights.asMap().entries.map((e) =>
              _InsightTile(insight: e.value, delay: e.key * 90)).toList());
        }),

        const SizedBox(height: 10),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 10),

        // ─ Footer ──────────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.psychology_rounded, size: 12,
              color: Color(0xFF6366F1)),
          const SizedBox(width: 6),
          Text('Analyse basée sur les données réelles de ta plateforme',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 10.5)),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _refresh,
              child: Text('Actualiser →',
                  style: TextStyle(
                      color: const Color(0xFFA5B4FC).withValues(alpha: 0.70),
                      fontSize: 10.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Chip données live ────────────────────────────────────────────────────────
class _LiveChip extends StatelessWidget {
  const _LiveChip(this.icon, this.label, this.color);
  final IconData icon; final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _InsightTile extends StatefulWidget {
  const _InsightTile({required this.insight, this.delay = 0});
  final _Insight insight;
  final int      delay;
  @override
  State<_InsightTile> createState() => _InsightTileState();
}
class _InsightTileState extends State<_InsightTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = _insightColor(widget.insight.type);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.insight.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.insight.title, style: TextStyle(
                    color: c, fontSize: 12.5, fontWeight: FontWeight.w700,
                    height: 1.2)),
                const SizedBox(height: 2),
                Text(widget.insight.detail, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 11, height: 1.3)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 8 · Graphique Revenus interactif — sélecteur de période + date personnalisée
// ═══════════════════════════════════════════════════════════════════════════════
