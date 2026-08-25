import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/national_reference.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSEAU vs NATIONAL — la bande de référence du cockpit.
//
//  Elle n'apparaît que sur UN examen, et seulement si le chiffre officiel a
//  été relevé. Sur « Tous les examens », il n'y a rien à comparer : un taux
//  national tous examens confondus n'existe pas.
//
//  Le geste est volontairement modeste — une bande, pas une carte de plus. Ce
//  qu'elle apporte n'est pas un indicateur supplémentaire mais un ÉTALON : le
//  même taux, mesuré par nous et proclamé par la DEC, à la même échelle.
// ════════════════════════════════════════════════════════════════════════════
class ExamNationalReferenceStrip extends StatelessWidget {
  const ExamNationalReferenceStrip({
    super.key,
    required this.reference,
    required this.examLabel,
    required this.networkRate,
    required this.admitted,
    required this.known,
  });

  final NationalReference reference;
  final String? examLabel;

  /// Taux du réseau, en pourcentage. `null` = rien de proclamé chez nous.
  final double? networkRate;
  final int admitted;
  final int known;

  @override
  Widget build(BuildContext context) {
    final delta = networkRate == null ? null : networkRate! - reference.rate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Figure(
            icon: Icons.school_rounded,
            color: kNavy,
            title: 'Notre réseau',
            // Deux nombres posés côte à côte pour être comparés doivent avoir
            // la MÊME précision : « 50,5 » face à « 51,61 » laisse croire à
            // deux mesures de nature différente.
            value: networkRate == null
                ? '—'
                : '${networkRate!.toStringAsFixed(2)} %',
            // Le taux ne s'affiche jamais sans son assiette : c'est ce qui
            // permet de le recouper avec la publication.
            detail: networkRate == null
                ? 'aucun résultat proclamé'
                : '$admitted admis / $known connus',
          ),
          _Figure(
            icon: Icons.account_balance_rounded,
            color: kListPurple,
            title: 'Proclamé par la DEC',
            value: '${reference.rate.toStringAsFixed(2)} %',
            detail: reference.hasCounts
                ? '${reference.admitted} admis / ${reference.present} présents'
                : 'taux publié, sans effectifs',
          ),
          if (delta != null) _DeltaChip(delta: delta),
          _Note(reference: reference, examLabel: examLabel),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: kTextMuted)),
              const SizedBox(height: 1),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    const SizedBox(width: 8),
                    Text(detail,
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ]),
            ],
          ),
        ],
      );
}

/// L'écart, en POINTS — jamais en pourcentage : « 2 % de plus » et « 2 points
/// de plus » sont deux choses différentes, et seule la seconde est vraie ici.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    // Sous deux points d'écart, parler d'avance ou de retard serait du bruit :
    // le réseau est au niveau du national, et c'est ce qu'il faut lire.
    final aligned = delta.abs() < 2;
    final color = aligned ? kTextMuted : (delta > 0 ? kGreen : kListOrange);
    final sign = delta > 0 ? '+' : '−';
    final label = aligned
        ? 'au niveau national'
        : '$sign${delta.abs().toStringAsFixed(1)} pt';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            aligned
                ? Icons.horizontal_rule_rounded
                : (delta > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded),
            size: 13,
            color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

/// La session de la référence est toujours nommée — sans quoi on comparerait
/// la campagne en cours à la proclamation de l'an dernier sans le dire.
class _Note extends StatelessWidget {
  const _Note({required this.reference, required this.examLabel});
  final NationalReference reference;
  final String? examLabel;

  @override
  Widget build(BuildContext context) {
    final exam = examLabel == null ? '' : '$examLabel · ';
    final text = reference.isCurrentSession
        ? '${exam}session ${reference.yearLabel}'
        : '${exam}dernière session proclamée : ${reference.yearLabel}';
    return Text(
      reference.sourceLabel == null
          ? text
          : '$text — source : ${reference.sourceLabel}',
      style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.35),
    );
  }
}
