import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ATOMES DE LECTURE D'UN RÉSULTAT — partagés par le classement, le détail
//  départemental et l'historique. Un écart au national se lit pareil partout :
//  en POINTS, avec sa flèche et sa couleur.
// ════════════════════════════════════════════════════════════════════════════
const Color kGoldMedal = Color(0xFFD4AF37);
const Color kSilverMedal = Color(0xFF9AA5B1);
const Color kBronzeMedal = Color(0xFFB87333);

Color medalColor(int rank) => switch (rank) {
      1 => kGoldMedal,
      2 => kSilverMedal,
      3 => kBronzeMedal,
      _ => kNavy,
    };

/// Écart au national — la seule mesure qui situe un département : 62 % ne se
/// juge pas dans l'absolu.
class ExamGapPill extends StatelessWidget {
  const ExamGapPill({super.key, required this.gap});
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = gap >= 0 ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(gap >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11, color: c),
        const SizedBox(width: 3),
        Text('${gap.abs().toStringAsFixed(2)} pt',
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
      ]),
    );
  }
}
