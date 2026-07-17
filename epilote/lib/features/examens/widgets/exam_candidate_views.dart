import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';
import 'exam_dossier_dialog.dart';
import 'exam_result_dialog.dart';
import 'examens_widgets.dart' show formatDate;
import 'student_history_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CANDIDATS — vues tableau/cartes avec sélection, + actions de ligne réutilisées.
//  Extraites de exam_candidate_list.dart : une seule définition des actions
//  (parcours, dossier, résultat, retrait) partagée par le tableau ET les cartes,
//  pour ne jamais les dupliquer.
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
    if (!canEdit) return history;

    return Row(mainAxisSize: MainAxisSize.min, children: [
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

// ─── Tableau ──────────────────────────────────────────────────────────────────
class ExamCandidateTable extends StatelessWidget {
  const ExamCandidateTable({
    super.key,
    required this.rows,
    required this.sessionId,
    required this.examCode,
    required this.canEdit,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<ExamCandidateRow> rows;
  final String sessionId;
  final String examCode;
  final bool canEdit;
  final Set<String> selected;
  final void Function(String id) onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final allSelected = rows.isNotEmpty && rows.every((r) => selected.contains(r.id));
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
          color: kNavy.withValues(alpha: 0.04),
          child: Row(children: [
            if (canEdit)
              SizedBox(
                width: 34,
                child: Checkbox(
                  value: allSelected,
                  tristate: false,
                  onChanged: (_) => onToggleAll(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              const SizedBox(width: 34),
            _h('CANDIDAT', flex: 4),
            _h('N° CANDIDAT', flex: 2),
            _h('DOSSIER', flex: 2),
            _h('RÉSULTAT', flex: 2),
            const SizedBox(width: 8),
            _h('', flex: 0, width: canEdit ? 148 : 40),
          ]),
        ),
        for (final (i, c) in rows.indexed)
          _TableRow(
            row: c,
            index: i + 1,
            striped: i.isOdd,
            sessionId: sessionId,
            examCode: examCode,
            canEdit: canEdit,
            checked: selected.contains(c.id),
            onToggle: () => onToggle(c.id),
          ),
      ]),
    );
  }

  Widget _h(String t, {required int flex, double? width}) {
    final child = Text(t,
        style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: kTextMuted));
    return width != null ? SizedBox(width: width, child: child) : Expanded(flex: flex, child: child);
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.index,
    required this.striped,
    required this.sessionId,
    required this.examCode,
    required this.canEdit,
    required this.checked,
    required this.onToggle,
  });

  final ExamCandidateRow row;
  final int index;
  final bool striped;
  final String sessionId;
  final String examCode;
  final bool canEdit;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = row;
    final (tone, label) = candidateDossierTone(c.dossierStatus, c.missingCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: checked
            ? kNavy.withValues(alpha: 0.05)
            : (striped ? kNavy.withValues(alpha: 0.02) : null),
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: canEdit
              ? Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : Text('$index',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(
                '${c.className ?? '—'} · ${c.matricule ?? 'sans matricule'}'
                '${c.dateOfBirth != null ? ' · né(e) le ${formatDate(c.dateOfBirth)}' : ''}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(c.candidateNumber ?? 'n° à venir',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    c.candidateNumber != null ? FontWeight.w700 : FontWeight.w400,
                color: c.candidateNumber != null ? kTextPrimary : kTextMuted,
              )),
        ),
        Expanded(
          flex: 2,
          child: Align(
              alignment: Alignment.centerLeft,
              child: CandidatePill(label: label, tone: tone)),
        ),
        Expanded(
          flex: 2,
          child: c.hasResult
              ? ResultChip(result: c.result!, average: c.average)
              : Text('en attente',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        const SizedBox(width: 8),
        ExamCandidateActions(
            row: c, canEdit: canEdit, sessionId: sessionId, examCode: examCode),
      ]),
    );
  }
}

// ─── Cartes ───────────────────────────────────────────────────────────────────
class ExamCandidateCards extends StatelessWidget {
  const ExamCandidateCards({
    super.key,
    required this.rows,
    required this.sessionId,
    required this.examCode,
    required this.canEdit,
    required this.selected,
    required this.onToggle,
  });

  final List<ExamCandidateRow> rows;
  final String sessionId;
  final String examCode;
  final bool canEdit;
  final Set<String> selected;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 720 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 150,
          ),
          itemCount: rows.length,
          itemBuilder: (_, i) => _CandidateCard(
            row: rows[i],
            sessionId: sessionId,
            examCode: examCode,
            canEdit: canEdit,
            checked: selected.contains(rows[i].id),
            onToggle: () => onToggle(rows[i].id),
          ),
        );
      });
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.row,
    required this.sessionId,
    required this.examCode,
    required this.canEdit,
    required this.checked,
    required this.onToggle,
  });

  final ExamCandidateRow row;
  final String sessionId;
  final String examCode;
  final bool canEdit;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = row;
    final (tone, label) = candidateDossierTone(c.dossierStatus, c.missingCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: checked ? kNavy.withValues(alpha: 0.6) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (canEdit)
              SizedBox(
                width: 30,
                height: 30,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            Expanded(
              child: Text(c.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
          ]),
          Padding(
            padding: EdgeInsets.only(left: canEdit ? 30 : 0),
            child: Text(
              '${c.className ?? '—'} · ${c.candidateNumber ?? 'n° à venir'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ),
          const Spacer(),
          Row(children: [
            CandidatePill(label: label, tone: tone),
            const SizedBox(width: 6),
            if (c.hasResult)
              Flexible(child: ResultChip(result: c.result!, average: c.average)),
            const Spacer(),
            ExamCandidateActions(
                row: c,
                canEdit: canEdit,
                sessionId: sessionId,
                examCode: examCode),
          ]),
        ],
      ),
    );
  }
}
