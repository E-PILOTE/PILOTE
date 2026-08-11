import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../models/dossier_piece_state.dart';
import '../providers/candidate_file_provider.dart';
import '../providers/exam_dossier_provider.dart';
import '../services/exam_export_service.dart';
import 'dossier_piece_tile.dart' show kListAmber, pieceVisual;
import 'exam_dossier_dialog.dart';
import 'student_history_dialog.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'INSCRIPTION — la candidature vue ENTIÈRE, d'un seul endroit.
//
//  Jusqu'ici une candidature se lisait en trois morceaux : une ligne de liste,
//  un dossier, un résultat. Ce qu'on présente au comptoir de la DEC, et ce
//  qu'on ressort quand un parent conteste, c'est pourtant l'ensemble.
//
//  L'écran signale aussi ce qui va COÛTER CHER plus tard : une date de
//  naissance absente (elle a déjà fait perdre des inscriptions entières à la
//  synchronisation), un dossier incomplet à l'approche de la clôture. Mieux
//  vaut le dire ici, où c'est encore réparable.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showCandidateFileDialog(
  BuildContext context, {
  required String candidateId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CandidateFileDialog(candidateId: candidateId),
    );

class _CandidateFileDialog extends ConsumerWidget {
  const _CandidateFileDialog({required this.candidateId});
  final String candidateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(candidateFileProvider(candidateId));
    final dossier = ref.watch(candidateDossierProvider(candidateId)).valueOrNull;

    return Dialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(messageErreur(e), style: TextStyle(color: kRed)),
          ),
          data: (c) => c == null
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Candidature introuvable.'))
              : _content(context, ref, c, dossier),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    CandidateFile c,
    CandidateDossier? dossier,
  ) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(c: c),
          Divider(height: 1, color: kBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._warnings(c, dossier),
                  _Section(title: 'IDENTITÉ', rows: [
                    ('Matricule', c.matricule ?? '—'),
                    ('Né(e) le', _fmt(c.dateOfBirth)),
                    ('Lieu de naissance', c.placeOfBirth ?? '—'),
                    ('Sexe', _gender(c.gender)),
                    ('Nationalité', c.nationality ?? '—'),
                  ]),
                  _Section(title: 'SCOLARITÉ', rows: [
                    ('Classe', c.className ?? '—'),
                    ('Filière', c.filiereLabel ?? '—'),
                    ('Niveau', c.levelName ?? '—'),
                    ('Redoublant', c.isRepeater ? 'Oui' : 'Non'),
                  ]),
                  _Section(title: 'CANDIDATURE', rows: [
                    ('Examen', c.examName ?? '—'),
                    ('Session', c.yearLabel ?? '—'),
                    ('N° candidat', c.candidateNumber ?? '—'),
                    ('Début des épreuves', _fmt(c.writtenFrom)),
                    ('Inscrit le', _fmt(c.registeredAt)),
                    ('Dossier déposé le', _fmt(c.submittedAt)),
                  ]),
                  if (dossier != null) _DossierBlock(dossier: dossier),
                  if (c.result != null && c.result != 'en_attente')
                    _Section(title: 'RÉSULTAT', rows: [
                      ('Décision', _result(c.result)),
                      if (c.average != null)
                        ('Moyenne', c.average!.toStringAsFixed(2)),
                      if (c.mention != null) ('Mention', c.mention!),
                      ('Proclamé le', _fmt(c.decidedAt)),
                      if (c.resultSource != null) ('Source', c.resultSource!),
                    ]),
                  if (c.notes?.trim().isNotEmpty ?? false)
                    _Section(title: 'OBSERVATIONS', rows: [('', c.notes!)]),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: kBorder),
          _Actions(c: c, dossier: dossier),
        ],
      );

  /// Ce qui va coûter cher si personne ne le voit maintenant.
  List<Widget> _warnings(CandidateFile c, CandidateDossier? d) {
    final out = <Widget>[];

    // Cause historique de perte silencieuse : sans date de naissance, le
    // serveur rejette la ligne et la transaction entière est abandonnée.
    if (c.dateOfBirth == null) {
      out.add(const _Warn(
        text: 'Date de naissance absente — la liste officielle l\'exige, et '
            'son absence fait échouer la synchronisation de la candidature.',
        tone: 0,
      ));
    }
    if (d != null && !d.isSubmitted && d.missingCount > 0) {
      out.add(_Warn(
        text: '${d.missingCount} pièce(s) manquante(s) — à réunir avant la '
            'clôture des inscriptions.',
        tone: 1,
      ));
    }
    if (out.isNotEmpty) out.add(const SizedBox(height: 8));
    return out;
  }
}

String _fmt(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _gender(String? g) => switch (g) {
      'M' => 'Masculin',
      'F' => 'Féminin',
      _ => '—',
    };

String _result(String? r) => switch (r) {
      'admis' => 'Admis',
      'ajourne' => 'Ajourné',
      'absent' => 'Absent',
      'fraude' => 'Fraude',
      _ => 'En attente',
    };

class _Head extends StatelessWidget {
  const _Head({required this.c});
  final CandidateFile c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: kNavy.withValues(alpha: 0.12),
            child: Text(
              _initials(c.fullName),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    c.examShortName ?? '',
                    if (c.yearLabel != null) 'session ${c.yearLabel}',
                    if (c.candidateNumber != null) 'n° ${c.candidateNumber}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: kTextMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 150,
                    child: Text(label,
                        style: TextStyle(fontSize: 12, color: kTextMuted)),
                  ),
                  Expanded(
                    child: Text(value,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                  ),
                ]),
              ),
          ],
        ),
      );
}

/// Résumé du dossier — l'état pièce par pièce, sans quitter la fiche.
class _DossierBlock extends StatelessWidget {
  const _DossierBlock({required this.dossier});
  final CandidateDossier dossier;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DOSSIER',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const SizedBox(height: 8),
            for (final p in dossier.mandatory)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Builder(builder: (_) {
                  final v = pieceVisual(
                      p.isStageLinked ? PieceFileState.verifiee : p.fileState);
                  return Row(children: [
                    Icon(v.icon, size: 15, color: v.tone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.piece.label,
                          style:
                              TextStyle(fontSize: 12.5, color: kTextPrimary)),
                    ),
                    Text(p.isStageLinked ? 'via Stages' : v.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: v.tone)),
                  ]);
                }),
              ),
          ],
        ),
      );
}

class _Warn extends StatelessWidget {
  const _Warn({required this.text, required this.tone});
  final String text;

  /// 0 = bloquant (rouge), 1 = à traiter (ambre).
  final int tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == 0 ? kRed : kListAmber;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(tone == 0 ? Icons.error_rounded : Icons.warning_amber_rounded,
            size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 11.5, color: color, height: 1.35)),
        ),
      ]),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.c, required this.dossier});
  final CandidateFile c;
  final CandidateDossier? dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    showStudentHistoryDialog(context,
                        studentId: c.studentId, fullName: c.fullName),
                icon: Icon(Icons.history_rounded, size: 16, color: kTextMuted),
                label: Text('Historique',
                    style: TextStyle(color: kTextMuted)),
              ),
              OutlinedButton.icon(
                onPressed: () => showExamDossierDialog(context,
                    candidateId: c.candidateId),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Dossier'),
                style: OutlinedButton.styleFrom(foregroundColor: kNavy),
              ),
              FilledButton.icon(
                onPressed: () => _print(context, ref),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Imprimer la fiche'),
                style: FilledButton.styleFrom(backgroundColor: kNavy),
              ),
            ]),
      );

  void _print(BuildContext context, WidgetRef ref) {
    final school =
        ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;
    final pieces = [
      for (final p in dossier?.mandatory ?? const <DossierPieceState>[])
        (
          label: p.piece.label,
          state: p.isStageLinked
              ? 'Via Stages'
              : pieceVisual(p.fileState).label,
        ),
    ];

    showPdfPreviewDialog(
      context,
      title: 'Fiche d\'inscription',
      subtitle: c.fullName,
      pdfFileName: 'Fiche_${c.fullName}.pdf'.replaceAll(' ', '_'),
      build: (_) => ExamExportService.buildCandidateFilePdf(
          c: c, schoolName: school, pieces: pieces),
      onDownload: () => ExamExportService.downloadCandidateFile(
          c: c, schoolName: school, pieces: pieces),
    );
  }
}
