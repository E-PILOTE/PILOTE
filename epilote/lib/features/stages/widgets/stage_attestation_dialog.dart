import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../providers/stage_actions.dart';
import '../providers/stages_provider.dart';
import '../services/stage_export_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ATTESTATION DE FIN DE STAGE — la pièce du dossier de baccalauréat.
//
//  La note officielle METP l'exige au dossier des bacs technique et
//  professionnel. Sans elle, l'élève NE S'INSCRIT PAS. Ce dialogue est donc le
//  point où le module Stages cesse d'être un registre et devient un maillon de
//  la chaîne d'examen.
//
//  ── Ce qu'il ne fait PAS ───────────────────────────────────────────────────
//  Il ne conditionne pas l'attestation à la note d'évaluation : le tuteur
//  d'entreprise ne rend pas toujours sa fiche, et refuser l'attestation pour ça
//  coûterait le bac à l'élève. La note est facultative — elle l'accompagne, elle
//  ne la commande pas.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showAttestationDialog(
  BuildContext context, {
  required InternshipRow row,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AttestationDialog(row: row),
    );

class _AttestationDialog extends ConsumerStatefulWidget {
  const _AttestationDialog({required this.row});
  final InternshipRow row;

  @override
  ConsumerState<_AttestationDialog> createState() => _State();
}

class _State extends ConsumerState<_AttestationDialog> {
  late DateTime _issuedAt = DateTime.now();
  final _grade = TextEditingController();
  final _comment = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _grade.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.studentName,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(
            r.hasAttestation
                ? 'Attestation délivrée'
                : 'Délivrer l\'attestation de fin de stage',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Why(),
              const SizedBox(height: 16),
              if (!r.hasAttestation) ...[
                _IssueDate(
                  value: _issuedAt,
                  onPick: (d) => setState(() => _issuedAt = d),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _grade,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Note du tuteur (facultative)',
                    hintText: 'ex. 14,5',
                    helperText:
                        'Le tuteur ne rend pas toujours sa fiche — la note '
                        'n\'empêche jamais l\'attestation.',
                    helperMaxLines: 2,
                    helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    labelStyle: TextStyle(color: kTextMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _comment,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Appréciation (facultative)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    labelStyle: TextStyle(color: kTextMuted),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Text('Documents',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _preview(convention: false),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                    label: const Text('Attestation'),
                    style: OutlinedButton.styleFrom(foregroundColor: kNavy),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _preview(convention: true),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('Convention'),
                    style: OutlinedButton.styleFrom(foregroundColor: kNavy),
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (r.hasAttestation)
          TextButton(
            onPressed: _saving ? null : _revoke,
            child: Text('Annuler l\'attestation',
                style: TextStyle(color: kRed)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
        if (!r.hasAttestation)
          FilledButton(
            onPressed: _saving ? null : _issue,
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            child: Text(_saving ? 'Délivrance…' : 'Délivrer'),
          ),
      ],
    );
  }

  double? _parseGrade() {
    final raw = _grade.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// Aperçu + impression d'un document du stage (attestation ou convention).
  /// On charge le détail complet (entreprise, tuteurs, évaluation) à la volée.
  Future<void> _preview({required bool convention}) async {
    final detail = await fetchStageDetail(widget.row.id);
    if (!mounted) return;
    if (detail == null) {
      setState(() => _error = 'Stage introuvable.');
      return;
    }
    final school =
        ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;
    final label = convention ? 'Convention' : 'Attestation';
    showPdfPreviewDialog(
      context,
      title: convention ? 'Convention de stage' : 'Attestation de fin de stage',
      subtitle: widget.row.studentName,
      pdfFileName: '${label}_${widget.row.studentName}.pdf',
      build: (_) => convention
          ? StageExportService.buildConventionPdf(s: detail, schoolName: school)
          : StageExportService.buildAttestationPdf(
              s: detail, schoolName: school),
      onDownload: () => convention
          ? StageExportService.downloadConvention(s: detail, schoolName: school)
          : StageExportService.downloadAttestation(
              s: detail, schoolName: school),
    );
  }

  Future<void> _issue() async {
    final g = _parseGrade();
    if (_grade.text.trim().isNotEmpty && g == null) {
      setState(() => _error = 'Note illisible. Exemple : 14,5');
      return;
    }
    if (g != null && (g < 0 || g > 20)) {
      setState(() => _error = 'Une note va de 0 à 20.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (g != null || _comment.text.trim().isNotEmpty) {
        await setInternshipEvaluation(widget.row.id,
            grade: g, comment: _comment.text);
      }
      await issueAttestation(widget.row.id, issuedAt: _issuedAt);
      ref.invalidate(stagesOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => _saving = true);
    try {
      await revokeAttestation(widget.row.id);
      ref.invalidate(stagesOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Dire l'enjeu, plutôt que de le laisser deviner. Un agent qui comprend qu'une
/// case vaut une année ne l'oublie pas.
class _Why extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.workspace_premium_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'L\'attestation de fin de stage est une pièce du dossier des '
              'baccalauréats technique et professionnel (note METP). Sans elle, '
              'le dossier est irrecevable.',
              style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.35),
            ),
          ),
        ]),
      );
}

class _IssueDate extends StatelessWidget {
  const _IssueDate({required this.value, required this.onPick});
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(now.year - 3),
            lastDate: now,
            helpText: 'Date de délivrance',
          );
          if (d != null) onPick(d);
        },
        icon: Icon(Icons.event_available_rounded, size: 16, color: kTextMuted),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Délivrée le ${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/${value.year}',
            style: TextStyle(fontSize: 12.5, color: kTextPrimary),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          minimumSize: const Size(double.infinity, 0),
        ),
      );
}
