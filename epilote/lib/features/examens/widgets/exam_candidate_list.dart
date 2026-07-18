import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/exam_candidates_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Candidats d'une session : KPI + briques du panneau (barre d'actions groupées,
//  états vides). La structure de défilement (CustomScrollView + slivers groupés)
//  et la logique de filtres/sélection vivent dans l'écran Session — ici, seuls
//  les composants réutilisables.
// ════════════════════════════════════════════════════════════════════════════

class ExamKpiRow extends StatelessWidget {
  const ExamKpiRow({super.key, required this.session, this.canWrite = false});
  final ExamSessionCandidates session;

  /// KPI selon le profil : la métrique d'écriture « Déposés » (dépôt des
  /// dossiers) ne ressort que pour qui peut agir sur les dossiers.
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final n = s.candidates.length;
    final rate = s.successRate;
    return KpiGrid(items: [
      // ── Socle : tout profil qui accède à la session ───────────────────────
      KpiData(
        label: 'Candidats',
        value: '$n',
        sub: 'inscrits à la session',
        icon: Icons.groups_rounded,
        color: kNavy,
        progressValue: n > 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Dossiers complets',
        value: '${s.complete}',
        sub: 'sur $n',
        icon: Icons.fact_check_rounded,
        color: n > 0 && s.complete == n ? kGreen : kRed,
        progressValue: n > 0 ? s.complete / n : 0,
        trend: n > 0 ? '${(s.complete * 100 / n).round()}%' : '—',
        trendUp: n > 0 && s.complete == n,
      ),
      KpiData(
        label: 'Taux de réussite',
        // Sur les résultats CONNUS : diviser par l'effectif afficherait 0 %
        // tant que rien n'est saisi — un chiffre faux et démoralisant.
        value: rate == null ? '—' : '${rate.toStringAsFixed(0)} %',
        sub: rate == null
            ? 'aucun résultat saisi'
            : '${s.admitted} admis sur ${s.withResult}',
        icon: Icons.emoji_events_rounded,
        color: rate == null ? kTextMuted : (rate >= 50 ? kGreen : kRed),
        progressValue: rate == null ? 0 : rate / 100,
        trend: rate == null ? '—' : (rate >= 50 ? 'bon' : 'à suivre'),
        trendUp: rate != null && rate >= 50,
      ),
      // ── Action : dépôt des dossiers, réservé à qui peut écrire ────────────
      if (canWrite)
        KpiData(
          label: 'Déposés',
          value: '${s.submitted}',
          sub: 'au centre d\'examen',
          icon: Icons.upload_file_rounded,
          color: s.submitted == 0 ? kTextMuted : kGreen,
          progressValue: n > 0 ? s.submitted / n : 0,
          trend: n > 0 ? '${(s.submitted * 100 / n).round()}%' : '—',
        ),
    ]);
  }
}

// ─── Barre d'actions groupées ─────────────────────────────────────────────────
class ExamBulkBar extends StatelessWidget {
  const ExamBulkBar({
    super.key,
    required this.selected,
    required this.onDeposit,
    required this.onRemove,
    required this.onClear,
    required this.onAssign,
  });

  final List<ExamCandidateRow> selected;
  final VoidCallback onDeposit, onRemove, onClear, onAssign;

  @override
  Widget build(BuildContext context) {
    final depositable =
        selected.where((r) => r.isComplete && !r.isSubmitted).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 18, color: kNavy),
        const SizedBox(width: 10),
        Text('${selected.length} sélectionné(s)',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const Spacer(),
        TextButton.icon(
          onPressed: onAssign,
          icon: const Icon(Icons.confirmation_number_outlined, size: 16),
          label: const Text('Centre et n° candidat'),
          style: TextButton.styleFrom(foregroundColor: kNavy),
        ),
        TextButton.icon(
          onPressed: depositable > 0 ? onDeposit : null,
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text('Marquer déposé(s)'
              '${depositable > 0 ? ' ($depositable)' : ''}'),
          style: TextButton.styleFrom(foregroundColor: kNavy),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.person_remove_outlined, size: 16),
          label: const Text('Retirer'),
          style: TextButton.styleFrom(foregroundColor: kRed),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded, size: 16),
          color: kTextMuted,
          tooltip: 'Vider la sélection',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class ExamNoMatch extends StatelessWidget {
  const ExamNoMatch({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Center(
          child: Text('Aucun candidat ne correspond au filtre.',
              style: TextStyle(fontSize: 13, color: kTextMuted)),
        ),
      );
}

class ExamEmptyCandidates extends StatelessWidget {
  const ExamEmptyCandidates({super.key});

  @override
  Widget build(BuildContext context) => Container(
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
          Text('Inscrivez les élèves classe par classe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}
