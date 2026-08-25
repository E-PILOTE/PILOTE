import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange;
import '../providers/admin_rattachement_provider.dart';
import 'origine_chip.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « Deux entrées pour la même année » — la panne rendue visible.
//
//  Le tarif réseau vise UNE entrée du référentiel. Quand les écoles se
//  répartissent sur deux entrées qui décrivent la même année, un tarif posé sur
//  l'une n'atteint pas les écoles de l'autre — sans erreur, sans message, sans
//  ligne rouge nulle part. Cette carte est le seul endroit qui le dit.
// ════════════════════════════════════════════════════════════════════════════
class DivergenceCard extends StatelessWidget {
  const DivergenceCard({super.key, required this.divergence});

  final Divergence divergence;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: kListOrange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kListOrange.withValues(alpha: 0.30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.call_split_rounded, size: 17, color: kListOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${divergence.cycle} — deux entrées pour la même année',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary),
              ),
            ),
            Text('${divergence.ecolesConcernees} école(s)',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
          const SizedBox(height: 10),
          for (final e in divergence.entrees) _branche(e),
          const SizedBox(height: 4),
          // Une école présente des DEUX côtés porte deux niveaux pour la même
          // année dans sa propre structure. Ce n'est plus une divergence de
          // doctrine entre établissements : c'est un doublon interne, et c'est
          // le cas le plus simple à trancher.
          if (divergence.ecolesDedoublees.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '⚠️ ${divergence.ecolesDedoublees.join(', ')} '
                '${divergence.ecolesDedoublees.length > 1 ? "portent" : "porte"} '
                'les DEUX entrées : deux niveaux pour la même année dans la '
                'même école.',
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kListOrange),
              ),
            ),
          ],
          Text(
            'Un tarif réseau posé sur l\'une de ces entrées n\'atteindra pas '
            'les écoles rattachées à l\'autre. Si ces deux lignes désignent la '
            'même année, rattachez les écoles à une seule d\'entre elles depuis '
            'la fiche de chaque établissement.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
          ),
        ]),
      );

  Widget _branche(EntreeReferentiel e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: e.duGroupe ? kNavy : kTextMuted,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(e.libelle,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            if (e.duGroupe) ...[
              const SizedBox(width: 8),
              const OrigineChip(),
            ],
            const SizedBox(width: 8),
            Text('${e.ecoles.length}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: kNavy)),
          ]),
          if (e.ecoles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 3),
              child: Text(
                e.ecoles.map((s) => s.schoolName).join(' · '),
                style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.3),
              ),
            ),
        ]),
      );
}
