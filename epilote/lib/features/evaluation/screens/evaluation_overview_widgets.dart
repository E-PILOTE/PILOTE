import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/evaluation_overview_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS PARTAGÉS de la vue d'ensemble Évaluation (Bulletins + Conseil de
//  classe) : en-tête trimestre, KPI hero, conversion couverture → unités du
//  panneau Cycle/Niveau/Classe, et liste de couverture par classe. Garantit un
//  design identique entre les deux pages, aligné sur le standard plateforme.
// ════════════════════════════════════════════════════════════════════════════

/// Unités du panneau Cycle/Niveau/Classe depuis la couverture par classe.
/// `okOf` = nombre d'unités « ok » d'une classe (bulletins générés, élèves
/// délibérés…). Le panneau n'agrège que des compteurs → synthétiser les unités
/// depuis les totaux par classe est exact et évite de requêter chaque élève.
List<ScopeUnit> evalScopeUnits(
    List<ClassCoverage> classes, int Function(ClassCoverage) okOf) {
  final units = <ScopeUnit>[];
  for (final c in classes) {
    final ok = okOf(c).clamp(0, c.students);
    for (var i = 0; i < c.students; i++) {
      units.add(ScopeUnit(
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder,
        classId: c.classId,
        className: c.className,
        ok: i < ok,
      ));
    }
  }
  return units;
}

/// Unités du panneau à raison d'UNE unité par classe (couverture « structure » :
/// toutes les classes apparaissent, même sans données). Utilisé par Notes, où la
/// métrique porte sur la classe (a des évaluations) et non sur l'élève.
List<ScopeUnit> evalClassUnits(
    List<ClassCoverage> classes, bool Function(ClassCoverage) okOf) {
  return [
    for (final c in classes)
      ScopeUnit(
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder,
        classId: c.classId,
        className: c.className,
        ok: okOf(c),
      ),
  ];
}

/// Filtre une couverture par le scope (cycle / niveau) sélectionné dans le panneau.
List<ClassCoverage> filterCoverage(List<ClassCoverage> classes, ScopeSel scope) {
  return [
    for (final c in classes)
      if ((scope.cycle == null || c.cycleCode == scope.cycle) &&
          (scope.level == null || c.levelCode == scope.level))
        c,
  ];
}

// ─── Libellé de section ──────────────────────────────────────────────────────
class EvalSectionLabel extends StatelessWidget {
  const EvalSectionLabel({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: kNavy),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: kNavy)),
      ]);
}

// ─── Guide « comment ça marche » (3 étapes numérotées) ───────────────────────
class EvalWorkflowGuide extends StatelessWidget {
  const EvalWorkflowGuide({super.key, required this.steps});

  /// (icône, titre, sous-titre) — une étape du parcours.
  final List<(IconData, String, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.route_rounded, size: 15, color: kNavy),
          SizedBox(width: 7),
          Text('Comment ça marche',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                  letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, cns) {
          final wide = cns.maxWidth >= 720;
          final tiles = <Widget>[
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(child: _StepTile(index: i + 1, step: steps[i])),
              if (i < steps.length - 1)
                wide
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 18, color: kTextMuted))
                    : const SizedBox.shrink(),
            ],
          ];
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: tiles)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StepTile(index: i + 1, step: steps[i]),
                      ),
                  ]);
        }),
      ]),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});
  final int index;
  final (IconData, String, String) step;
  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = step;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: kNavy, borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Text('$index',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: kNavy),
            const SizedBox(width: 5),
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.25, color: kTextMuted)),
        ]),
      ),
    ]);
  }
}

// ─── En-tête : titre de section + sélecteur de trimestre ─────────────────────
class EvalTrimesterHeader extends StatelessWidget {
  const EvalTrimesterHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trims,
    required this.trimesterId,
    required this.onTrimester,
  });
  final String title, subtitle;
  final List trims; // List<TrimesterModel>
  final String? trimesterId;
  final ValueChanged<String?> onTrimester;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            initialValue: trimesterId,
            isExpanded: true,
            decoration:
                adminFilledInput('Trimestre', icon: Icons.date_range_rounded),
            items: [
              for (final t in trims)
                DropdownMenuItem(
                    value: t.id as String, child: Text(t.label as String)),
            ],
            onChanged: onTrimester,
          ),
        ),
      ]),
    );
  }
}

// ─── KPI hero (cartes paramétrées par la page) ───────────────────────────────
class EvalHeroKpis extends StatelessWidget {
  const EvalHeroKpis({super.key, required this.cards});

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

// ─── Liste de couverture par classe (cartes cliquables) ──────────────────────
class EvalCoverageList extends StatelessWidget {
  const EvalCoverageList({
    super.key,
    required this.classes,
    required this.metricLabel,
    required this.okOf,
    required this.onOpen,
    this.totalOf,
    this.openLabel = 'Ouvrir',
  });
  final List<ClassCoverage> classes;
  final String metricLabel, openLabel;
  final int Function(ClassCoverage) okOf;

  /// Dénominateur de la progression (défaut : effectif élèves). Notes l'utilise
  /// pour rapporter à son nombre d'évaluations.
  final int Function(ClassCoverage)? totalOf;
  final ValueChanged<ClassCoverage> onOpen;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
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
        itemCount: classes.length,
        itemBuilder: (_, i) => _CoverageCard(
          c: classes[i],
          metricLabel: metricLabel,
          ok: okOf(classes[i]),
          total: (totalOf ?? (x) => x.students)(classes[i]),
          openLabel: openLabel,
          onTap: () => onOpen(classes[i]),
        ),
      );
    });
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.c,
    required this.metricLabel,
    required this.ok,
    required this.total,
    required this.openLabel,
    required this.onTap,
  });
  final ClassCoverage c;
  final String metricLabel, openLabel;
  final int ok, total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = scopeCycleColor(c.cycleCode);
    final pct = total == 0 ? 0.0 : ok / total;
    final metricColor = total == 0
        ? kTextMuted
        : (ok >= total
            ? kGreen
            : (ok == 0 ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9)));
    return Material(
      color: Colors.white,
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
                          Text(c.className,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary)),
                          Text(
                              '${c.levelCode ?? scopeCycleName(c.cycleCode)} · '
                              '${c.students} élèves',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: kTextMuted)),
                        ]),
                  ),
                  if (c.classAverage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kNavy.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('${c.classAverage!.toStringAsFixed(2)}/20',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kNavy)),
                    ),
                ]),
                const Spacer(),
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
                Row(children: [
                  Text('$ok/$total ${metricLabel.toLowerCase()}',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: metricColor)),
                  const Spacer(),
                  Row(children: [
                    Text(openLabel,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: kNavy),
                  ]),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── Chip de scope actif (réutilisé) ─────────────────────────────────────────
class EvalScopeChip extends StatelessWidget {
  const EvalScopeChip({super.key, required this.label, required this.onClear});
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
            const Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}
