import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../students/widgets/scope_drilldown_panel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  KIT PARTAGÉ « VIE SCOLAIRE » — chrome commun aux 6 modules (Présences,
//  Cantine, Discipline, Orientation, Infirmerie, Bibliothèque) pour un design
//  100% cohérent avec le reste de la plateforme : en-tête (titre + sélecteurs),
//  hero KPI, panneau Cycle ▸ Niveau ▸ Classe (réutilise ScopeDrilldownPanel) +
//  couverture par classe, chips/labels/guide.
// ════════════════════════════════════════════════════════════════════════════

// ─── Modèle générique de couverture par classe ───────────────────────────────
class VsCoverageRow {
  const VsCoverageRow({
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.total,
    required this.ok,
    this.note,
  });
  final String classId, className;
  final String? cycleCode, levelCode, note;
  final int levelOrder;
  final int total; // dénominateur (effectif élèves de la classe)
  final int ok; // numérateur (métrique : appel fait, élèves orientés, etc.)
}

/// Unités du panneau (1 par élève) : la métrique « ok » d'une classe est
/// répartie sur ses élèves → barres de couverture exactes par cycle/niveau.
List<ScopeUnit> vsScopeUnits(List<VsCoverageRow> rows) {
  final units = <ScopeUnit>[];
  for (final r in rows) {
    final ok = r.ok.clamp(0, r.total);
    for (var i = 0; i < r.total; i++) {
      units.add(ScopeUnit(
        cycleCode: r.cycleCode,
        levelCode: r.levelCode,
        levelOrder: r.levelOrder,
        classId: r.classId,
        className: r.className,
        ok: i < ok,
      ));
    }
  }
  return units;
}

/// Une unité PAR CLASSE (couverture « structure » : toutes les classes visibles
/// même sans données ; ok = la classe satisfait le critère).
List<ScopeUnit> vsClassUnits(
    List<VsCoverageRow> rows, bool Function(VsCoverageRow) okOf) {
  return [
    for (final r in rows)
      ScopeUnit(
        cycleCode: r.cycleCode,
        levelCode: r.levelCode,
        levelOrder: r.levelOrder,
        classId: r.classId,
        className: r.className,
        ok: okOf(r),
      ),
  ];
}

/// Fil « Cycle ▸ Niveau » (sans la classe — le titre la porte déjà), pour les
/// en-têtes de tiroirs (clarté de structure, cohérente avec le reste de l'app).
String vsCrumb(String? cycleCode, String? levelCode) => [
      scopeCycleName(cycleCode),
      if ((levelCode ?? '').isNotEmpty) levelCode!,
    ].join('  ▸  ');

List<VsCoverageRow> vsFilterScope(List<VsCoverageRow> rows, ScopeSel scope) => [
      for (final r in rows)
        if ((scope.cycle == null || r.cycleCode == scope.cycle) &&
            (scope.level == null || r.levelCode == scope.level))
          r,
    ];

// ─── En-tête : titre + sous-titre + zone de sélecteurs (fournie par le module) ─
class VsHeader extends StatelessWidget {
  const VsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title, subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ]),
    );
  }
}

// ─── Hero KPI ─────────────────────────────────────────────────────────────────
class VsHeroKpis extends StatelessWidget {
  const VsHeroKpis({super.key, required this.cards});

  /// (icône, libellé, valeur, couleur, sous-titre).
  final List<(IconData, String, String, Color, String?)> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final (icon, label, value, color, sub) = cards[i];
          return AdminStatCard(
              label: label, value: value, icon: icon, color: color, subtitle: sub);
        },
      );
    });
  }
}

// ─── Sélecteur filled (date / période / liste) homogène ──────────────────────
class VsPickerBox extends StatelessWidget {
  const VsPickerBox({
    super.key,
    required this.icon,
    required this.child,
    this.width = 220,
    this.onTap,
  });
  final IconData icon;
  final Widget child;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: kTextMuted),
        const SizedBox(width: 8),
        Expanded(child: child),
        if (onTap != null)
          Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
      ]),
    );
    return SizedBox(
      width: width,
      child: onTap == null
          ? box
          : InkWell(
              onTap: onTap, borderRadius: BorderRadius.circular(8), child: box),
    );
  }
}

// ─── Couverture par classe (cartes cliquables) ───────────────────────────────
class VsCoverageList extends StatelessWidget {
  const VsCoverageList({
    super.key,
    required this.rows,
    required this.metricLabel,
    required this.onOpen,
    this.openLabel = 'Ouvrir',
    this.showProgress = true,
  });
  final List<VsCoverageRow> rows;
  final String metricLabel, openLabel;
  final ValueChanged<VsCoverageRow> onOpen;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: AdminEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Aucune classe',
          message: 'Aucune classe ne correspond à ce filtre.',
        ),
      );
    }
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) => _CoverageCard(
          r: rows[i],
          metricLabel: metricLabel,
          openLabel: openLabel,
          showProgress: showProgress,
          onTap: () => onOpen(rows[i]),
        ),
      );
    });
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.r,
    required this.metricLabel,
    required this.openLabel,
    required this.showProgress,
    required this.onTap,
  });
  final VsCoverageRow r;
  final String metricLabel, openLabel;
  final bool showProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = scopeCycleColor(r.cycleCode);
    final pct = r.total == 0 ? 0.0 : r.ok / r.total;
    final metricColor = r.total == 0
        ? kTextMuted
        : (r.ok >= r.total
            ? kGreen
            : (r.ok == 0 ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9)));
    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.class_rounded, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.className,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary)),
                          Text(
                              '${r.levelCode ?? scopeCycleName(r.cycleCode)} · '
                              '${r.total} élèves',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: kTextMuted)),
                        ]),
                  ),
                  if (r.note != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kNavy.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(r.note!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kNavy)),
                    ),
                ]),
                const Spacer(),
                if (showProgress) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: kSurface,
                      valueColor: AlwaysStoppedAnimation(metricColor),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Row(children: [
                  Text('${r.ok}/${r.total} ${metricLabel.toLowerCase()}',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: metricColor)),
                  const Spacer(),
                  Row(children: [
                    Text(openLabel,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: kNavy),
                  ]),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── Chip de scope actif / libellé de section ────────────────────────────────
class VsScopeChip extends StatelessWidget {
  const VsScopeChip({super.key, required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

class VsSectionLabel extends StatelessWidget {
  const VsSectionLabel({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: kNavy),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: kNavy)),
      ]);
}
