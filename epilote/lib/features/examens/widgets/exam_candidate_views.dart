import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';
import 'candidate_file_dialog.dart';
import 'exam_dossier_dialog.dart';
import 'exam_result_dialog.dart';
import 'student_history_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CANDIDATS — briques PARTAGÉES : ton du dossier, actions de ligne, puces.
//  Le rendu (groupé par classe, virtualisé) vit dans exam_candidate_grouped.dart
//  et réutilise ces briques — une seule définition des actions, jamais dupliquée.
// ════════════════════════════════════════════════════════════════════════════

(Color, String) candidateDossierTone(String? status, int missing) =>
    switch (status) {
      'valide' => (kGreen, 'Validé'),
      'depose' => (kGreen, 'Déposé'),
      'complet' => (kNavy, 'Complet'),
      'rejete' => (kRed, 'Rejeté'),
      _ => (kRed, missing > 0 ? 'Incomplet · $missing pièce(s)' : 'Incomplet'),
    };

/// Les actions d'un candidat — UNE seule définition, partagée tableau/cartes.
/// Le parcours reste consultable sans droit d'écriture ; le reste est gaté.
class ExamCandidateActions extends ConsumerWidget {
  const ExamCandidateActions({
    super.key,
    required this.row,
    required this.canEdit,
    required this.sessionId,
    required this.examCode,
  });

  final ExamCandidateRow row;
  final bool canEdit;
  final String sessionId;
  final String examCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La fiche est une LECTURE : elle reste offerte à un agent sans droit
    // d'écriture, qui doit pouvoir relire une candidature et l'imprimer.
    final fiche = IconButton(
      onPressed: () =>
          showCandidateFileDialog(context, candidateId: row.id),
      icon: const Icon(Icons.badge_outlined, size: 18),
      color: kNavy,
      tooltip: 'Fiche d\'inscription complète',
      visualDensity: VisualDensity.compact,
    );

    final history = IconButton(
      onPressed: () => showStudentHistoryDialog(
        context,
        studentId: row.studentId,
        fullName: row.fullName,
        forExamCode: examCode,
      ),
      icon: const Icon(Icons.history_rounded, size: 18),
      color: kTextMuted,
      tooltip: 'Parcours — examens et stages',
      visualDensity: VisualDensity.compact,
    );
    if (!canEdit) {
      return Row(mainAxisSize: MainAxisSize.min, children: [fiche, history]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      fiche,
      history,
      IconButton(
        onPressed: () => showExamDossierDialog(context, candidateId: row.id),
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        color: row.missingCount > 0 ? kRed : kTextMuted,
        tooltip: row.missingCount > 0
            ? '${row.missingCount} pièce(s) manquante(s)'
            : 'Dossier',
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        onPressed: () =>
            showExamResultDialog(context, row: row, sessionId: sessionId),
        icon: const Icon(Icons.emoji_events_outlined, size: 18),
        color: row.hasResult ? kGreen : kTextMuted,
        tooltip: row.hasResult ? 'Modifier le résultat' : 'Saisir le résultat',
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        onPressed: row.isSubmitted ? null : () => _confirmRemove(context, ref),
        icon: const Icon(Icons.person_remove_outlined, size: 18),
        color: row.isSubmitted ? kTextMuted.withValues(alpha: 0.4) : kTextMuted,
        tooltip: row.isSubmitted
            ? 'Dossier déposé — retrait impossible'
            : 'Retirer la candidature',
        visualDensity: VisualDensity.compact,
      ),
    ]);
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Retirer ${row.fullName} ?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: Text(
          'La candidature est supprimée. L\'élève, lui, n\'est pas touché : il '
          'reste inscrit dans sa classe et pourra être réinscrit à cette session.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await unregisterCandidate(row.id);
    ref.invalidate(sessionCandidatesProvider(sessionId));
  }
}

// ─── Puces réutilisées ────────────────────────────────────────────────────────
class CandidatePill extends StatelessWidget {
  const CandidatePill({super.key, required this.label, required this.tone});
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

class ResultChip extends StatelessWidget {
  const ResultChip({super.key, required this.result, this.average});
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
          result == 'admis' ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 14,
          color: tone),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          average != null ? '$label ${average!.toStringAsFixed(2)}' : label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: tone),
        ),
      ),
    ]);
  }
}
