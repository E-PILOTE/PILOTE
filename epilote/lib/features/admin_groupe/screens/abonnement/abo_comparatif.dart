part of '../admin_subscription_screen.dart';

// Matrice comparative et tickets.

class _ComparisonMatrix extends StatelessWidget {
  const _ComparisonMatrix({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final plans = data.plans;
    final cats = data.allCategories;
    final currentId = data.subscription?.planId;

    String limit(int v, {bool money = false}) {
      if (v <= 0 && !money) return 'Illimité';
      if (money) return v == 0 ? 'Gratuit' : fmtXaf(v);
      return fmtInt(v);
    }

    final rows = <_MatrixRow>[
      _MatrixRow('Tarif', Icons.payments_rounded,
          plans.map((p) => p.priceXaf == 0
              ? 'Gratuit'
              : '${limit(p.priceXaf, money: true)} / ${p.periodSuffix}').toList(),
          highlight: true),
      _MatrixRow('Périodicité', Icons.event_repeat_rounded,
          plans.map((p) => p.periodLabel).toList()),
      _MatrixRow('Écoles', Icons.school_rounded, plans.map((p) => limit(p.maxSchools)).toList()),
      _MatrixRow('Élèves', Icons.groups_rounded, plans.map((p) => limit(p.maxStudents)).toList()),
      _MatrixRow('Personnel', Icons.badge_rounded, plans.map((p) => limit(p.maxStaff)).toList()),
      _MatrixRow('Modules', Icons.extension_rounded, plans.map((p) => '${p.moduleCount}').toList()),
      for (final c in cats)
        _MatrixRow(c.name, Icons.category_rounded,
            plans.map((p) {
              final n = p.modulesInCategory(c.slug);
              return n == 0 ? '—' : '$n';
            }).toList(),
            isCategory: true),
    ];

    const labelColW = 180.0;
    const minPlanColW = 120.0;
    final minTableW = labelColW + plans.length * minPlanColW;

    Widget buildTable(double planColW) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MatrixHeaderRow(plans: plans, currentId: currentId,
                labelColW: labelColW, planColW: planColW),
            ...rows.asMap().entries.map((e) => _MatrixDataRow(
                  row: e.value, plans: plans, currentId: currentId,
                  zebra: e.key.isOdd, labelColW: labelColW, planColW: planColW,
                )),
          ],
        );

    return AdminCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (_, c) {
          // Sur grand écran : colonnes plans s'élargissent pour remplir la largeur.
          if (c.maxWidth > minTableW) {
            final planColW = (c.maxWidth - labelColW) / plans.length;
            return buildTable(planColW);
          }
          // Sur petit écran : scroll horizontal avec largeur min.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minTableW, child: buildTable(minPlanColW)),
          );
        }),
      ),
    );
  }
}

class _MatrixRow {
  _MatrixRow(this.label, this.icon, this.values,
      {this.highlight = false, this.isCategory = false});
  final String label;
  final IconData icon;
  final List<String> values;
  final bool highlight;
  final bool isCategory;
}

class _MatrixHeaderRow extends StatelessWidget {
  const _MatrixHeaderRow({
    required this.plans, required this.currentId,
    this.labelColW = 180, this.planColW = 120,
  });
  final List<PlanOption> plans;
  final String? currentId;
  final double labelColW;
  final double planColW;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kNavyDark, kNavy]),
      ),
      child: Row(children: [
        SizedBox(
          width: labelColW,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text('Caractéristiques',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        ...plans.map((p) {
          final isCurrent = p.id == currentId;
          return SizedBox(
            width: planColW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                if (isCurrent) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Actuel',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

class _MatrixDataRow extends StatelessWidget {
  const _MatrixDataRow({
    required this.row,
    required this.plans,
    required this.currentId,
    required this.zebra,
    this.labelColW = 180,
    this.planColW = 120,
  });
  final _MatrixRow row;
  final List<PlanOption> plans;
  final String? currentId;
  final bool zebra;
  final double labelColW;
  final double planColW;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: zebra ? kSurface.withValues(alpha: 0.5) : kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      // IntrinsicHeight : indispensable car la matrice est rendue dans un
      // SingleChildScrollView vertical (hauteur non bornée). Sans cela,
      // `CrossAxisAlignment.stretch` reçoit une hauteur infinie → crash layout.
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: labelColW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(row.icon, size: 15, color: row.isCategory ? kTextMuted : kNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: row.highlight ? FontWeight.w800 : FontWeight.w600,
                          color: kTextPrimary)),
                ),
              ]),
            ),
          ),
          ...List.generate(plans.length, (i) {
            final isCurrent = plans[i].id == currentId;
            final val = i < row.values.length ? row.values[i] : '—';
            final muted = val == '—';
            return Container(
              width: planColW,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrent ? kGreen.withValues(alpha: 0.06) : null,
                border: Border(left: BorderSide(color: kBorder)),
              ),
              child: Text(val,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: row.highlight ? FontWeight.w800 : FontWeight.w600,
                    color: muted ? Colors.grey.shade400 : (row.highlight ? planColor(plans[i].slug) : kTextPrimary),
                  )),
            );
          }),
        ]),
      ),
    );
  }
}

// ─── Ligne ticket (demande) ───────────────────────────────────────────────────
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.t});
  final SubscriptionTicket t;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (t.status) {
      'open'        => (kAccent, 'En attente'),
      'in_progress' => (kNavy, 'En traitement'),
      'resolved'    => (kGreen, 'Résolu'),
      'closed'      => (kTextMuted, 'Clôturé'),
      _             => (kTextMuted, t.status),
    };
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(t.subject,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            AdminBadge(label, color: color),
          ]),
          if (t.body != null && t.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.body!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
          ],
          if (t.response != null && t.response!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGreen.withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.support_agent_rounded, size: 16, color: kGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(t.response!, style: TextStyle(fontSize: 12.5, color: kTextPrimary, height: 1.4))),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Text(_dateLabel(t.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    return 'Envoyée le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
