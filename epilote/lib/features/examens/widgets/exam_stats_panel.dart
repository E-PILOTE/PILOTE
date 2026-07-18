import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/exam_stats.dart';
import '../providers/exam_candidates_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS DE LA SESSION — le chiffre que le ministère lira.
//
//  Le taux porte sur les résultats CONNUS, et l'assiette est TOUJOURS écrite à
//  côté (« 42 résultats connus sur 60 »). Un pourcentage sans son dénominateur
//  est un mensonge commode : à 2 résultats sur 300, « 100 % de réussite » est
//  vrai et pourtant trompeur.
//
//  Tant que rien n'est proclamé, on n'affiche PAS 0 % — on dit qu'on attend.
// ════════════════════════════════════════════════════════════════════════════

class ExamStatsPanel extends StatelessWidget {
  const ExamStatsPanel({super.key, required this.rows});

  final List<ExamCandidateRow> rows;

  @override
  Widget build(BuildContext context) {
    final stats = computeExamStats([
      for (final r in rows)
        ExamStatInput(
          result: r.result ?? 'en_attente',
          className: r.className,
          filiereLabel: r.filiereLabel,
          gender: r.gender,
          mention: r.mention,
        ),
    ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_rounded, size: 18, color: kNavy),
            const SizedBox(width: 8),
            Text('Résultats de la session',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ]),
          const SizedBox(height: 14),
          if (!stats.hasResults)
            _awaiting(stats.overall.total)
          else ...[
            _headline(stats.overall),
            const SizedBox(height: 18),
            if (stats.byClass.length > 1) ...[
              _group('PAR CLASSE', stats.byClass),
              const SizedBox(height: 14),
            ],
            if (stats.byFiliere.length > 1) ...[
              _group('PAR FILIÈRE', stats.byFiliere),
              const SizedBox(height: 14),
            ],
            _group('PAR SEXE', stats.byGender),
            if (stats.mentions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _mentions(stats.mentions),
            ],
          ],
        ],
      ),
    );
  }

  /// Session non proclamée : on le DIT, on n'affiche pas un taux de zéro.
  Widget _awaiting(int total) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.hourglass_empty_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              total == 0
                  ? 'Aucun candidat inscrit à cette session.'
                  : 'Aucun résultat proclamé pour l\'instant — $total '
                      'candidat(s) en attente. Le taux de réussite s\'affichera '
                      'dès la première saisie.',
              style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _headline(ExamStatLine o) {
    final rate = o.rate ?? 0;
    final tone = rate >= 0.75 ? kGreen : (rate >= 0.5 ? kNavy : kRed);

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('${(rate * 100).round()} %',
          style: TextStyle(
              fontSize: 34, fontWeight: FontWeight.w900, color: tone)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('de réussite',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            // L'assiette, toujours. Sans elle, « 100 % » sur 2 résultats
            // laisserait croire à un triomphe.
            Text(
              '${o.admitted} admis sur ${o.known} résultat(s) connu(s)'
              '${o.pending > 0 ? ' · ${o.pending} en attente' : ''}',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _group(String title, List<ExamStatLine> lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextMuted)),
          const SizedBox(height: 8),
          for (final l in lines) _StatBar(line: l),
        ],
      );

  Widget _mentions(Map<String, int> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MENTIONS (ADMIS)',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in entries)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${e.key} · ${e.value}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGreen)),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.line});
  final ExamStatLine line;

  @override
  Widget build(BuildContext context) {
    final rate = line.rate;
    final tone = rate == null
        ? kTextMuted
        : (rate >= 0.75 ? kGreen : (rate >= 0.5 ? kNavy : kRed));

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(line.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: kTextPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate ?? 0,
              minHeight: 6,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            // Jamais un taux sans son assiette, même sur une ligne ventilée.
            rate == null
                ? 'en attente'
                : '${(rate * 100).round()} % (${line.admitted}/${line.known})',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tone),
          ),
        ),
      ]),
    );
  }
}
