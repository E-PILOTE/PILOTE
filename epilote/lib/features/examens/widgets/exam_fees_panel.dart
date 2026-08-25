import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_fees_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECOUVREMENT DES FRAIS D'EXAMEN — le revenu que l'école doit lever.
//
//  Les frais d'examen sont un revenu de l'école, donc du groupe scolaire. Ils
//  ne vivent pas dans un coin du module Examens : chaque encaissement est une
//  ligne `student_payments` ordinaire, donc il apparaît dans le module
//  Paiements et remonte au revenu SANS aucun recâblage. La relation avec
//  Finance n'est pas un pont ajouté après coup — c'est la même chaîne.
// ════════════════════════════════════════════════════════════════════════════

final _fmt = NumberFormat.decimalPattern('fr');
String formatXaf(int v) => '${_fmt.format(v)} FCFA';

class ExamFeesPanel extends ConsumerWidget {
  const ExamFeesPanel({
    super.key,
    required this.sessionId,
    required this.examShortName,
    required this.yearLabel,
  });

  final String sessionId;
  final String examShortName;
  final String? yearLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examFeesProvider(sessionId));

    // Plus de permission à tester ici : ce panneau ne fait plus qu'AFFICHER.
    // Il n'y a plus rien à « gérer » — le montant appartient au ministère.
    return async.when(
      loading: () => const SizedBox(height: 96),
      error: (e, _) => const SizedBox.shrink(),
      data: (d) => _card(d),
    );
  }

  Widget _card(ExamFeeData d) {
    final s = d.summary;
    final tone = s.expected == 0
        ? kTextMuted
        : (s.remaining == 0 ? kGreen : (s.rate >= 0.5 ? kNavy : kRed));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.payments_rounded, size: 18, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Frais d\'examen — recouvrement',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            if (d.amountPerCandidate > 0)
              Text('${formatXaf(d.amountPerCandidate)} / candidat',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kNavy)),
          ]),
          if (d.amountPerCandidate == 0) ...[
            const SizedBox(height: 8),
            _hint(
              'Aucun montant fixé pour cette session. Les frais d\'examen sont '
              'fixés par le ministère : tant qu\'il n\'a rien publié, aucun '
              'recouvrement n\'est attendu et aucun encaissement n\'est possible.',
              kTextMuted,
            ),
          ] else if (!d.baremePublie) ...[
            const SizedBox(height: 8),
            // ⚠️ Ce panneau laissait l'école FIXER elle-même le montant, par
            // « Définir le montant » puis `setExamFeeAmount`. C'était la
            // surfacturation livrée comme une fonctionnalité : la DEC fixe ces
            // frais nationalement. Retiré le 5 août 2026.
            _hint(
              'Montant porté par la session nationale. Le ministère n\'a pas '
              'encore publié le barème de cette session : aucun encaissement '
              'ne peut y être rattaché.',
              kAccent,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 22, runSpacing: 12, children: [
            _Stat(label: 'Attendu', value: formatXaf(s.expected), tone: kNavy),
            _Stat(
                label: 'Encaissé', value: formatXaf(s.collected), tone: kGreen),
            _Stat(
                label: 'Reste à recouvrer',
                value: formatXaf(s.remaining),
                tone: s.remaining > 0 ? kRed : kGreen),
            _Stat(
                label: 'Taux',
                value: '${(s.rate * 100).round()} %',
                tone: tone),
          ]),
          if (s.expected > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.rate,
                minHeight: 7,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${s.candidates} candidat(s) inscrit(s) · les encaissements '
              'apparaissent dans le module Paiements et dans le revenu de '
              'l\'école.',
              style: TextStyle(fontSize: 10.5, color: kTextMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hint(String text, Color tone) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: tone),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 11, color: tone, height: 1.35)),
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});
  final String label, value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: tone)),
        ],
      );
}
