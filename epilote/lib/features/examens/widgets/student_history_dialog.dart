import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/student_history_provider.dart';
import 'examens_widgets.dart' show formatDate;

// ════════════════════════════════════════════════════════════════════════════
//  PARCOURS D'UN ÉLÈVE — ses examens et ses stages, toutes années.
//
//  Un élève passe le BEPC, puis le BET, puis le bac : c'est une trajectoire, pas
//  une session isolée. Cet écran la montre — et s'en sert.
// ════════════════════════════════════════════════════════════════════════════

/// Diplômes antérieurs acceptés pour s'inscrire à un examen donné.
/// Source : note officielle METP (cf. migration 0052).
/// Le BET n'y figure pas : il suit la 3e technique et n'exige aucun diplôme.
const kPrerequisites = <String, Set<String>>{
  'BAC_T': {'BEPC', 'BET', 'BEP'},
  'BAC_P': {'BEPC', 'BET', 'BEP'},
  'BEP': {'BEPC', 'BET'},
  'CAP': {'BEPC', 'BET'},
  'BTF': {'BEPC', 'BET'},
};

Future<void> showStudentHistoryDialog(
  BuildContext context, {
  required String studentId,
  required String fullName,
  String? forExamCode,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _StudentHistoryDialog(
        studentId: studentId,
        fullName: fullName,
        forExamCode: forExamCode,
      ),
    );

class _StudentHistoryDialog extends ConsumerWidget {
  const _StudentHistoryDialog({
    required this.studentId,
    required this.fullName,
    this.forExamCode,
  });

  final String studentId;
  final String fullName;

  /// Si fourni, l'écran vérifie le prérequis de CET examen (§ éligibilité).
  final String? forExamCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentHistoryProvider(studentId));

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fullName,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text('Parcours — examens et stages',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
          data: (h) => h.isEmpty
              ? _Empty()
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (forExamCode != null) ...[
                        _Eligibility(history: h, examCode: forExamCode!),
                        const SizedBox(height: 16),
                      ],
                      if (h.exams.isNotEmpty) ...[
                        _Label('Examens', trailing: '${h.exams.length}'),
                        const SizedBox(height: 8),
                        for (final e in h.exams) _ExamTile(entry: e),
                      ],
                      if (h.internships.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Label('Stages', trailing: '${h.internships.length}'),
                        const SizedBox(height: 8),
                        for (final i in h.internships) _StageTile(entry: i),
                      ],
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
      ],
    );
  }
}

// ── Éligibilité : ce que nous savons déjà, sans demander à la DEC ───────────
class _Eligibility extends StatelessWidget {
  const _Eligibility({required this.history, required this.examCode});
  final StudentHistory history;
  final String examCode;

  @override
  Widget build(BuildContext context) {
    final required = kPrerequisites[examCode];
    if (required == null) return const SizedBox.shrink();

    final found = history.diplomaAmong(required);
    final ok = found != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? kGreen : kRed).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (ok ? kGreen : kRed).withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.verified_rounded : Icons.help_outline_rounded,
            size: 16, color: ok ? kGreen : kRed),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ok
                    ? '${found.examShortName} obtenu — session ${found.yearLabel ?? '?'}'
                    : 'Aucun diplôme antérieur trouvé chez nous',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ok ? kGreen : kRed),
              ),
              const SizedBox(height: 2),
              Text(
                ok
                    // Le savoir ne dispense pas de la pièce : la légalisation est
                    // un objet physique, et c'est le rejet le plus banal au comptoir.
                    ? 'La copie légalisée reste due au dossier.'
                    : 'Requis : ${required.join(', ')}. L\'élève l\'a peut-être '
                        'obtenu ailleurs — à vérifier sur pièce, pas à refuser.',
                style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.entry});
  final ExamHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (Color tone, String label) = switch (e.result) {
      'admis' => (kGreen, 'Admis'),
      'ajourne' => (kRed, 'Ajourné'),
      'absent' => (kTextMuted, 'Absent'),
      'fraude' => (kRed, 'Fraude'),
      _ => (kTextMuted, 'En attente'),
    };

    final sub = <String>[
      if (e.yearLabel != null) e.yearLabel!,
      if (e.className != null) e.className!,
      if (e.isRepeater) 'redoublant',
      if (e.candidateNumber != null) 'n° ${e.candidateNumber}',
      if (e.decidedAt != null) 'proclamé le ${formatDate(e.decidedAt)}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.examShortName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              if (sub.isNotEmpty)
                Text(sub.join(' · '),
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ),
        if (e.average != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              '${e.average!.toStringAsFixed(2)}${e.mention != null ? ' · ${e.mention}' : ''}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
        ),
      ]),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.entry});
  final InternshipHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final i = entry;
    final sub = <String>[
      if (i.yearLabel != null) i.yearLabel!,
      if (i.companyName != null) i.companyName!,
      if (i.startDate != null)
        '${formatDate(i.startDate)}${i.endDate != null ? ' → ${formatDate(i.endDate)}' : ''}',
      if (i.grade != null) '${i.grade!.toStringAsFixed(1)}/20',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.title ?? 'Stage',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              if (sub.isNotEmpty)
                Text(sub.join(' · '),
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ),
        // L'attestation est LA pièce : sans elle, pas de dossier de bac.
        Icon(
          i.hasAttestation
              ? Icons.workspace_premium_rounded
              : Icons.pending_outlined,
          size: 16,
          color: i.hasAttestation ? kGreen : kTextMuted,
        ),
        const SizedBox(width: 5),
        Text(
          i.hasAttestation ? 'Attestation' : 'Sans attestation',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: i.hasAttestation ? kGreen : kTextMuted,
          ),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: kTextMuted)),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(trailing!, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      ]);
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(children: [
          Icon(Icons.history_rounded, size: 32, color: kTextMuted),
          const SizedBox(height: 10),
          Text('Aucun examen ni stage enregistré',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(
            'Le parcours se remplit à mesure des inscriptions et des stages.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ]),
      );
}
