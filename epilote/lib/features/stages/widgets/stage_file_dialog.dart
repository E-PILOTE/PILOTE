import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../services/powersync/student_document_upload.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../models/stage_detail.dart';
import '../providers/stage_actions.dart';
import '../providers/stage_documents.dart';
import '../providers/stages_provider.dart';
import 'stage_form_dialog.dart';
import '../services/stage_export_service.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'UN STAGE — le stage vu entier, et ses pièces réelles.
//
//  Le stage n'est pas un registre : pour un bac technique ou professionnel il
//  conditionne l'inscription à l'examen. Ce qui le prouve — la convention
//  signée revenue de l'entreprise, la fiche d'évaluation du tuteur — n'existait
//  jusqu'ici que sur papier. Ici on le dépose, on le relit, on l'imprime.
// ════════════════════════════════════════════════════════════════════════════

const _kSlug = 'stages';
const _kExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

Future<void> showStageFileDialog(
  BuildContext context, {
  required String internshipId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _StageFileDialog(internshipId: internshipId),
    );

class _StageFileDialog extends ConsumerStatefulWidget {
  const _StageFileDialog({required this.internshipId});
  final String internshipId;

  @override
  ConsumerState<_StageFileDialog> createState() => _State();
}

class _State extends ConsumerState<_StageFileDialog> {
  final _busy = <String>{};
  String? _error;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stageDetailProvider(widget.internshipId));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));

    return Dialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(messageErreur(e), style: TextStyle(color: kRed)),
          ),
          data: (s) => s == null
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Stage introuvable.'))
              : _content(s, canEdit),
        ),
      ),
    );
  }

  Widget _content(StageDetail s, bool canEdit) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head(s),
          Divider(height: 1, color: kBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!,
                        style: TextStyle(
                            fontSize: 12,
                            color: kRed,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                  ],
                  _Section(title: 'ÉLÈVE', rows: [
                    ('Nom et prénom', s.studentName),
                    ('Matricule', s.matricule ?? '—'),
                    ('Classe', s.className ?? '—'),
                    ('Filière', s.filiereLabel ?? '—'),
                  ]),
                  _Section(title: 'ENTREPRISE', rows: [
                    ('Raison sociale', s.companyName ?? '—'),
                    ('Secteur', s.companySector ?? '—'),
                    ('Adresse',
                        (s.companyPlace?.trim().isNotEmpty ?? false)
                            ? s.companyPlace!
                            : '—'),
                    ('Contact', s.companyContact ?? '—'),
                    ('Tuteur entreprise', s.companyTutorName ?? '—'),
                    ('Téléphone du tuteur', s.companyTutorPhone ?? '—'),
                  ]),
                  _Section(title: 'STAGE', rows: [
                    ('Intitulé', s.title ?? '—'),
                    ('Du', _fmt(s.startDate)),
                    ('Au', _fmt(s.endDate)),
                    ('Tuteur école', s.schoolTutorName ?? '—'),
                    ('Convention signée le', _fmt(s.conventionSignedAt)),
                    ('Attestation délivrée le', _fmt(s.attestationIssuedAt)),
                  ]),
                  if (s.evaluationGrade != null ||
                      (s.evaluationComment?.trim().isNotEmpty ?? false))
                    _Section(title: 'ÉVALUATION', rows: [
                      if (s.evaluationGrade != null)
                        ('Note du tuteur',
                            '${s.evaluationGrade!.toStringAsFixed(2)} / 20'),
                      if (s.evaluationComment?.trim().isNotEmpty ?? false)
                        ('Appréciation', s.evaluationComment!),
                    ]),
                  _documents(s, canEdit),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: kBorder),
          _actions(s, canEdit),
        ],
      );

  Widget _head(StageDetail s) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
        child: Row(children: [
          Icon(Icons.work_history_rounded, color: kNavy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.studentName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  [s.companyName, s.className]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' · '),
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

  Widget _documents(StageDetail s, bool canEdit) {
    final docs = ref.watch(stageDocumentsProvider(s.id)).valueOrNull ?? const [];
    final byType = {for (final d in docs) d.type: d};

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PIÈCES DU STAGE',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kTextMuted)),
          const SizedBox(height: 8),
          for (final e in stageDocTypes.entries)
            _DocSlot(
              label: e.value,
              doc: byType[e.key],
              busy: _busy.contains(e.key),
              readOnly: !canEdit,
              onAttach: () => _attach(s, e.key),
              onPreview: () => _preview(byType[e.key]!.fileUrl),
              onRemove: () => _remove(e.key, byType[e.key]!.id),
            ),
        ],
      ),
    );
  }

  Widget _actions(StageDetail s, bool canEdit) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              // ⚠️ CORRIGER se garde sur `update`, SUPPRIMER sur `delete`.
              // Ce ne sont pas le même geste : réparer une date de frappe et
              // effacer la trace d'un stage n'engagent pas la même
              // responsabilité, et la base distingue déjà les deux verbes.
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () => _corriger(s),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Corriger'),
                  style: OutlinedButton.styleFrom(foregroundColor: kNavy),
                ),
              if (ref.watch(canProvider((slug: _kSlug, action: 'delete'))))
                OutlinedButton.icon(
                  onPressed: () => _supprimer(s),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(foregroundColor: kRed),
                ),
              OutlinedButton.icon(
                onPressed: () => _pdf(s, convention: true),
                icon: const Icon(Icons.description_rounded, size: 16),
                label: const Text('Convention'),
                style: OutlinedButton.styleFrom(foregroundColor: kNavy),
              ),
              FilledButton.icon(
                onPressed: () => _pdf(s, convention: false),
                icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                label: const Text('Attestation'),
                style: FilledButton.styleFrom(backgroundColor: kNavy),
              ),
            ]),
      );

  // ─── Gestes ───────────────────────────────────────────────────────────────

  /// Rouvre le formulaire, prérempli, sur ce stage.
  Future<void> _corriger(StageDetail s) async {
    final modifie = await showStageFormDialog(context, stage: s);
    if (!modifie || !mounted) return;
    ref.invalidate(stageDetailProvider(s.id));
  }

  /// Effacer un stage — un doublon, une ligne créée sur le mauvais élève.
  ///
  /// ⚠️ La confirmation NOMME l'élève. « Supprimer ce stage ? » sur une fiche
  /// qu'on vient d'ouvrir par erreur se valide sans lire ; le nom force à
  /// vérifier qu'on est bien sur la bonne ligne.
  ///
  /// ⚠️ Et elle prévient quand une ATTESTATION a été délivrée : la pièce est
  /// peut-être déjà dans un dossier de bac, où elle continuera d'exister
  /// pendant que le stage aura disparu de l'école.
  Future<void> _supprimer(StageDetail s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Supprimer ce stage ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le stage de ${s.studentName}'
              '${s.companyName == null ? '' : ' chez ${s.companyName}'} sera '
              'effacé. Les pièces déjà générées ne le seront pas.',
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
            if (s.hasAttestation) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Une attestation a été délivrée pour ce stage. Elle est '
                  'peut-être déjà dans un dossier de baccalauréat, où elle '
                  'restera — alors que le stage, lui, aura disparu de l’école.',
                  style: TextStyle(fontSize: 12, color: kRed, height: 1.4),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _run('suppression', () async {
      await deleteInternship(s.id);
      ref.invalidate(stagesOverviewProvider);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() {
      _busy.add(key);
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _attach(StageDetail s, String slug) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kExtensions,
      withData: true,
    );
    final f = res?.files.firstOrNull;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;

    await _run(
      slug,
      () => attachStageDocument(
        internshipId: s.id,
        studentId: s.studentId,
        groupId: s.groupId,
        schoolId: s.schoolId,
        typeSlug: slug,
        fileName: f.name,
        bytes: bytes,
        client: ref.read(supabaseClientProvider),
      ),
    );
  }

  Future<void> _remove(String slug, String documentId) =>
      _run(slug, () => removeStageDocument(documentId));

  Future<void> _preview(String path) async {
    final url = await signedStudentDocumentUrl(
        ref.read(supabaseClientProvider), path);
    if (!mounted) return;
    if (url == null) {
      setState(() => _error =
          'Aperçu indisponible hors connexion — la pièce est enregistrée et '
          'partira à la prochaine synchronisation.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _pdf(StageDetail s, {required bool convention}) {
    final school =
        ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;
    showPdfPreviewDialog(
      context,
      title: convention ? 'Convention de stage' : 'Attestation de fin de stage',
      subtitle: s.studentName,
      pdfFileName:
          '${convention ? 'Convention' : 'Attestation'}_${s.studentName}.pdf'
              .replaceAll(' ', '_'),
      build: (_) => convention
          ? StageExportService.buildConventionPdf(s: s, schoolName: school)
          : StageExportService.buildAttestationPdf(s: s, schoolName: school),
      onDownload: () => convention
          ? StageExportService.downloadConvention(s: s, schoolName: school)
          : StageExportService.downloadAttestation(s: s, schoolName: school),
    );
  }
}

String _fmt(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

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
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 160,
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

class _DocSlot extends StatelessWidget {
  const _DocSlot({
    required this.label,
    required this.doc,
    required this.busy,
    required this.readOnly,
    required this.onAttach,
    required this.onPreview,
    required this.onRemove,
  });

  final String label;
  final StageDocument? doc;
  final bool busy, readOnly;
  final VoidCallback onAttach, onPreview, onRemove;

  @override
  Widget build(BuildContext context) {
    final has = doc != null;
    final tone = has ? kGreen : kTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Icon(has ? Icons.insert_drive_file_rounded : Icons.upload_file_rounded,
            size: 17, color: tone),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ),
        if (busy)
          const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else if (has) ...[
          TextButton(
            onPressed: onPreview,
            child: Text('Aperçu',
                style: TextStyle(fontSize: 11.5, color: kNavy)),
          ),
          if (!readOnly)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              color: kRed,
              visualDensity: VisualDensity.compact,
              tooltip: 'Retirer',
            ),
        ] else if (!readOnly)
          TextButton(
            onPressed: onAttach,
            child: Text('Joindre',
                style: TextStyle(fontSize: 11.5, color: kNavy)),
          ),
      ]),
    );
  }
}
