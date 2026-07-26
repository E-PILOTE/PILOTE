import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../examens/models/exam_stats.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VENTILATION DE LA RÉUSSITE — par FILIÈRE ou par DÉPARTEMENT (cockpit METP).
//
//  Les deux axes que pilote un ministère technique : ajuster l'offre de
//  formation (filière) et l'équité territoriale (département). Le taux suit la
//  règle unique du réseau (cf. exam_stats.dart) : calculé sur les résultats
//  CONNUS, et affiché « en attente » — jamais 0 % — tant que rien n'est
//  proclamé. L'assiette (admis / connus) accompagne toujours le pourcentage.
// ════════════════════════════════════════════════════════════════════════════
class ExamRateBreakdown extends StatelessWidget {
  const ExamRateBreakdown({
    super.key,
    required this.title,
    required this.icon,
    required this.lines,
    this.subtitle,
    this.maxRows = 8,
  });

  final String title;
  final IconData icon;
  final List<ExamStatLine> lines;
  final String? subtitle;
  final int maxRows;

  static const _amber = Color(0xFFF59E0B);

  /// Couleur sémantique du taux (vert bon · ambre moyen · rouge faible ·
  /// gris « en attente »). Distincte de l'accent de marque.
  static Color _rateColor(double? r) {
    if (r == null) return kTextMuted;
    if (r >= 0.70) return kGreen;
    if (r >= 0.50) return _amber;
    return kRed;
  }

  @override
  Widget build(BuildContext context) {
    final shown = lines.take(maxRows).toList();
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(title, icon: icon, subtitle: subtitle),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune donnée pour cet axe.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          )
        else
          for (final l in shown) _RateRow(line: l),
      ]),
    );
  }
}

/// Les deux ventilations côte à côte (empilées en étroit) : filière + département.
class ExamBreakdownRow extends StatelessWidget {
  const ExamBreakdownRow({
    super.key,
    required this.filiere,
    required this.departement,
  });
  final List<ExamStatLine> filiere;
  final List<ExamStatLine> departement;

  @override
  Widget build(BuildContext context) {
    final f = ExamRateBreakdown(
      title: 'Réussite par filière',
      icon: Icons.category_rounded,
      lines: filiere,
      subtitle: 'Pilotage de l’offre de formation technique',
    );
    final d = ExamRateBreakdown(
      title: 'Réussite par département',
      icon: Icons.public_rounded,
      lines: departement,
      subtitle: 'Équité territoriale',
    );
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 820) {
        return Column(children: [f, const SizedBox(height: 16), d]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: f),
        const SizedBox(width: 16),
        Expanded(child: d),
      ]);
    });
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.line});
  final ExamStatLine line;

  @override
  Widget build(BuildContext context) {
    final rate = line.rate; // null tant qu'aucun résultat n'est connu
    final color = ExamRateBreakdown._rateColor(rate);
    final pct = rate == null ? null : (rate * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        // Libellé de l'axe (filière / département). Largeur généreuse et police
        // légèrement resserrée : « Bâtiment et Génie civil » doit se lire ENTIER
        // — un nom de filière tronqué devant un ministère ne se rattrape pas.
        SizedBox(
          width: 158,
          child: Text(line.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ),
        // Barre proportionnelle au taux (ou état « en attente »)
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: rate == null
                ? Container(
                    height: 12,
                    alignment: Alignment.centerLeft,
                    color: kTextMuted.withValues(alpha: 0.10),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: rate.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (ctx, v, _) => Stack(children: [
                      Container(height: 12, color: color.withValues(alpha: 0.10)),
                      FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ]),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // Taux + assiette (admis / connus) — ou « en attente »
        SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pct == null ? 'en attente' : '$pct %',
                style: TextStyle(
                    fontSize: pct == null ? 11 : 13,
                    fontWeight: FontWeight.w800,
                    fontStyle:
                        pct == null ? FontStyle.italic : FontStyle.normal,
                    color: pct == null ? kTextMuted : color),
              ),
              Text(
                pct == null
                    ? '${line.total} inscrit${line.total > 1 ? 's' : ''}'
                    : '${line.admitted}/${line.known} connus',
                style: TextStyle(fontSize: 10, color: kTextMuted),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
