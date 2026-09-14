import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/subscriptions_provider.dart';
import 'subs_style.dart';

// ─── Les six cartes du haut ─────────────────────────────────────────────
//  Dont le « Revenu mensuel », qui annonçait 120 000 F là où « Économie » en
//  calculait 184 000. Le squelette de chargement vit ici aussi : il dessine
//  ces six cartes, et doit changer avec elles.

class _KD {
  const _KD({
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true,
    this.progressValue,
  });
  final String  label, value;
  final String? sub, trend;
  final bool    trendUp;
  final double? progressValue;
  final IconData icon;
  final Color   color;
}

class SubKpiGrid extends StatelessWidget {
  const SubKpiGrid({super.key, required this.data});
  final SubscriptionsData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Abonnements', value: '$n',
        sub:   '${data.actifs} actifs · ${data.trials} essais',
        icon:  Icons.workspace_premium_rounded, color: kSubNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Abonnements actifs', value: '${data.actifs}',
        sub:   'Payants en cours',
        icon:  Icons.check_circle_rounded, color: kSubGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Payants' : '—',
      ),
      _KD(
        label: 'En essai', value: '${data.trials}',
        sub:   'Période d\'essai',
        icon:  Icons.hourglass_top_rounded, color: kSubGold,
        progressValue: n > 0 ? data.trials / n : 0,
        trend: data.trials > 0 ? '${data.trials} en test' : 'Aucun',
        trendUp: data.trials > 0,
      ),
      _KD(
        label: 'Inactifs', value: '${data.inactifs}',
        sub:   'Suspendus / expirés / annulés',
        icon:  Icons.pause_circle_rounded, color: kSubMuted,
        progressValue: n > 0 ? data.inactifs / n : 0,
        trend: data.inactifs > 0 ? '${data.inactifs} hors-service' : '—',
        trendUp: false,
      ),
      _KD(
        label: 'Expire bientôt', value: '${data.expiringSoon}',
        sub:   'Échéance ≤ 30 jours',
        icon:  Icons.event_busy_rounded, color: kSubOrange,
        progressValue: data.actifs > 0 ? data.expiringSoon / data.actifs : 0,
        trend: data.expiringSoon > 0 ? '⚠️ À relancer' : 'OK',
        trendUp: data.expiringSoon == 0,
      ),
      // ⚠️ Ce chiffre annonçait 120 000 F là où « Économie & licences » en
      // calculait 184 000 : il additionnait le tarif de BASE des plans et
      // perdait les écoles supplémentaires ainsi que les tarifs négociés.
      // Deux écrans du même logiciel se contredisaient de 35 % sur le chiffre
      // d'affaires — et c'est CETTE page, celle qu'on ouvre en premier, qui
      // sous-estimait. Le calcul est maintenant partagé (`tarifPlanRow`).
      //
      // Les licences de tutelle restent hors de ce total, et c'est voulu : le
      // plan « Licence de tutelle » est un support à 0 F, le marché se compte
      // dans Économie. Le sous-titre le dit, pour qu'un zéro apparent ne passe
      // pas pour un oubli.
      _KD(
        label: 'Revenu mensuel', value: '${subMoney(data.mrr)} F',
        sub:   'Abonnements — hors licences',
        icon:  Icons.payments_rounded, color: kSubPurple,
        progressValue: data.mrr > 0 ? 1 : 0,
        trend: data.mrr > 0 ? '📈 Récurrent' : '—',
        trendUp: data.mrr > 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kSubBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kSubBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        ), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(
                          color: kSubMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: kSubSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kSubBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: d.trendUp ? d.color : kSubOrange,
                            fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ]),
                  ]),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SubShimmerSkeleton extends StatelessWidget {
  const SubShimmerSkeleton({super.key});

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 14,
              mainAxisSpacing: 14, childAspectRatio: 2.6,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
          ),
          const SizedBox(height: 20),
          _box(double.infinity, 120, r: 14),
          const SizedBox(height: 16),
          _box(180, 18, r: 8),
          const SizedBox(height: 16),
          _box(double.infinity, 48, r: 6),
          const SizedBox(height: 1),
          ...List.generate(6, (_) => Column(children: [
            const SizedBox(height: 1),
            _box(double.infinity, 56, r: 0),
          ])),
        ]),
      ),
    );
  }
}
