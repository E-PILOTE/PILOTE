import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_candidates_provider.dart';
import 'examens_widgets.dart' show formatDate;

// ════════════════════════════════════════════════════════════════════════════
//  Liste des candidats + KPI de session.
// ════════════════════════════════════════════════════════════════════════════

class ExamKpiRow extends StatelessWidget {
  const ExamKpiRow({super.key, required this.session});
  final ExamSessionCandidates session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final rate = s.successRate;
    final cards = <(IconData, String, String, Color, String?)>[
      (Icons.groups_rounded, 'Candidats', '${s.candidates.length}', kNavy, null),
      (
        Icons.fact_check_rounded,
        'Dossiers complets',
        '${s.complete}',
        s.complete == s.candidates.length && s.candidates.isNotEmpty
            ? kGreen
            : kRed,
        'sur ${s.candidates.length}',
      ),
      (
        Icons.upload_file_rounded,
        'Déposés',
        '${s.submitted}',
        s.submitted == 0 ? kTextMuted : kGreen,
        'au centre d\'examen',
      ),
      (
        Icons.emoji_events_rounded,
        'Taux de réussite',
        // Sur les résultats CONNUS : diviser par l'effectif afficherait 0 %
        // tant que rien n'est saisi — un chiffre faux et démoralisant.
        rate == null ? '—' : '${rate.toStringAsFixed(0)} %',
        rate == null ? kTextMuted : (rate >= 50 ? kGreen : kRed),
        rate == null
            ? 'aucun résultat saisi'
            : '${s.admitted} admis sur ${s.withResult} résultat(s)',
      ),
    ];

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

class ExamCandidateList extends ConsumerWidget {
  const ExamCandidateList({
    super.key,
    required this.rows,
    required this.sessionId,
  });
  final List<ExamCandidateRow> rows;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Icon(Icons.person_off_outlined, size: 36, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucun candidat',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Inscrivez les élèves depuis la page Examens, classe par classe.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        for (final (i, c) in rows.indexed) _Row(row: c, index: i + 1),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.index});
  final ExamCandidateRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = row;
    final (Color tone, String label) = switch (c.dossierStatus) {
      'valide' => (kGreen, 'Validé'),
      'depose' => (kGreen, 'Déposé'),
      'complet' => (kNavy, 'Complet'),
      'rejete' => (kRed, 'Rejeté'),
      _ => (kRed, 'Incomplet'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: index == 1
            ? null
            : Border(top: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('$index',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.fullName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(
                '${c.className ?? '—'} · ${c.matricule ?? 'sans matricule'}'
                '${c.dateOfBirth != null ? ' · né(e) le ${formatDate(c.dateOfBirth)}' : ''}',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            c.candidateNumber ?? 'n° à venir',
            style: TextStyle(
              fontSize: 12,
              fontWeight: c.candidateNumber != null
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: c.candidateNumber != null ? kTextPrimary : kTextMuted,
            ),
          ),
        ),
        _Pill(
          label: c.missingCount > 0 ? '$label · ${c.missingCount} pièce(s)' : label,
          tone: tone,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: c.hasResult
              ? _ResultChip(result: c.result!, average: c.average)
              : Text('en attente',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
      ]),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.result, this.average});
  final String result;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final (Color tone, String label) = switch (result) {
      'admis' => (kGreen, 'Admis'),
      'ajourne' => (kRed, 'Ajourné'),
      'absent' => (kTextMuted, 'Absent'),
      'fraude' => (kRed, 'Fraude'),
      _ => (kTextMuted, '—'),
    };
    return Row(children: [
      Icon(
        result == 'admis' ? Icons.check_circle_rounded : Icons.cancel_rounded,
        size: 14,
        color: tone,
      ),
      const SizedBox(width: 5),
      Text(
        average != null ? '$label ${average!.toStringAsFixed(2)}' : label,
        style:
            TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tone),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
      );
}
