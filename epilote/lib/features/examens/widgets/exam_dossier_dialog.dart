import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../models/dossier_piece_state.dart';
import '../models/exam_dossier_piece.dart';
import '../providers/exam_dossier_actions.dart';
import '../providers/exam_dossier_provider.dart';
import 'dossier_piece_tile.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER D'UN CANDIDAT — le pré-contrôle avant le comptoir.
//
//  Pourquoi cet écran existe : la DEC vérifie les pièces AU COMPTOIR. Si l'école
//  a vérifié AVANT, elle n'est pas renvoyée. C'est le seul moment où c'est
//  réparable — après la clôture, une pièce manquante coûte une année à l'élève.
//
//  Chaque pièce est un EMPLACEMENT : on y joint le scan réel, on le relit, on
//  le fait vérifier. Ce que rien ne peut dématérialiser (chemise, enveloppe,
//  frais) garde une case — étiquetée pour ce qu'elle est.
//
//  Les gestes s'enregistrent IMMÉDIATEMENT. Un bouton « Enregistrer » ajouterait
//  un dernier moyen de tout perdre la veille d'une clôture ; il n'y en a pas.
// ════════════════════════════════════════════════════════════════════════════

const _kSlug = 'examens';
const _kExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

Future<void> showExamDossierDialog(
  BuildContext context, {
  required String candidateId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExamDossierDialog(candidateId: candidateId),
    );

class _ExamDossierDialog extends ConsumerStatefulWidget {
  const _ExamDossierDialog({required this.candidateId});
  final String candidateId;

  @override
  ConsumerState<_ExamDossierDialog> createState() => _State();
}

class _State extends ConsumerState<_ExamDossierDialog> {
  /// Codes des pièces en cours de traitement (téléversement, retrait…).
  final _busy = <String>{};
  String? _error;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(candidateDossierProvider(widget.candidateId));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canValidate =
        ref.watch(canProvider((slug: _kSlug, action: 'validate')));

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: async.maybeWhen(
        data: (d) => d == null
            ? const Text('Dossier')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.fullName,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text('Dossier ${d.examShortName}',
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
        orElse: () => const Text('Dossier'),
      ),
      content: SizedBox(
        width: 520,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
          data: (d) => d == null
              ? const Text('Candidature introuvable.')
              : _body(d, canEdit),
        ),
      ),
      actions: [
        if (async.valueOrNull?.isSubmitted == true && canValidate)
          TextButton.icon(
            onPressed: _reopen,
            icon: Icon(Icons.lock_open_rounded, size: 16, color: kAccent),
            label: Text('Rouvrir', style: TextStyle(color: kAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
      ],
    );
  }

  Widget _body(CandidateDossier d, bool canEdit) {
    // Un dossier déposé est FIGÉ : il a été transmis, il ne doit plus bouger
    // en douce. La réouverture est un acte explicite, gardé et tracé.
    final readOnly = d.isSubmitted || !canEdit;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Banner(missing: d.missingCount, submitted: d.isSubmitted),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(
                    fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          for (final p in d.mandatory)
            if (p.isStageLinked)
              // Satisfaite par le module Stages — la source de vérité de
              // l'attestation. Pas une case : le système le sait déjà.
              _StageLinkedTile(stage: p.linkedStage!)
            else
              DossierPieceTile(
                state: p,
                readOnly: readOnly,
                busy: _busy.contains(p.piece.code),
                onAttach: () => _attach(d, p.piece),
                onPreview: () => _preview(p.attached!),
                onRemove: () => _remove(d, p),
                onToggleVerify: (v) => _verify(d, p, v),
                onToggleDeclared: (v) => _declare(d, p.piece.code, v),
              ),
          if (d.conditional.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('LE CAS ÉCHÉANT',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const SizedBox(height: 6),
            // Sans case, et volontairement : nous ne savons pas qui est inapte
            // à l'EPS. Le deviner produirait un dossier faux ; la DEC tranche.
            for (final p in d.conditional) _ConditionalNote(piece: p.piece),
          ],
        ],
      ),
    );
  }

  // ─── Gestes ───────────────────────────────────────────────────────────────

  Future<void> _run(String code, Future<void> Function() action) async {
    setState(() {
      _busy.add(code);
      _error = null;
    });
    try {
      await action();
      ref.invalidate(candidateDossierProvider(widget.candidateId));
    } on DossierFrozenException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy.remove(code));
    }
  }

  Future<void> _attach(CandidateDossier d, ExamDossierPiece piece) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kExtensions,
      withData: true,
    );
    final f = res?.files.firstOrNull;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;

    await _run(
      piece.code,
      () => attachDossierPiece(
        candidateId: d.candidateId,
        studentId: d.studentId,
        groupId: d.groupId,
        schoolId: d.schoolId,
        piece: piece,
        fileName: f.name,
        bytes: bytes,
        client: ref.read(supabaseClientProvider),
      ),
    );
  }

  Future<void> _remove(CandidateDossier d, DossierPieceState p) => _run(
        p.piece.code,
        () => removeDossierPiece(
          candidateId: d.candidateId,
          documentId: p.attached!.documentId,
        ),
      );

  Future<void> _verify(CandidateDossier d, DossierPieceState p, bool v) => _run(
        p.piece.code,
        () => setDossierPieceVerified(
          candidateId: d.candidateId,
          documentId: p.attached!.documentId,
          verified: v,
          verifiedBy: ref.read(authNotifierProvider).valueOrNull?.id,
        ),
      );

  Future<void> _declare(CandidateDossier d, String code, bool v) => _run(
        code,
        () {
          final declared = {
            for (final p in d.mandatory)
              if (p.declared) p.piece.code,
          };
          v ? declared.add(code) : declared.remove(code);
          return saveDossierDeclarations(d.candidateId, declared: declared);
        },
      );

  /// Ouvre le scan dans le lecteur du système via une URL signée (bucket privé).
  Future<void> _preview(AttachedPiece a) async {
    final url =
        await signedPieceUrl(ref.read(supabaseClientProvider), a.fileUrl);
    if (!mounted) return;
    if (url == null) {
      setState(() => _error =
          'Aperçu indisponible hors connexion — le scan est bien enregistré '
          'et partira à la prochaine synchronisation.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _reopen() => _run(
        '__reopen__',
        () => reopenDossier(widget.candidateId),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.missing, required this.submitted});
  final int missing;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final (Color tone, IconData icon, String text) = submitted
        ? (kGreen, Icons.lock_rounded, 'Dossier déposé — pièces figées.')
        : missing == 0
            ? (kGreen, Icons.check_circle_rounded, 'Toutes les pièces sont là.')
            : (
                kRed,
                Icons.error_rounded,
                '$missing pièce(s) manquante(s) — à réunir avant la clôture.'
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: tone)),
        ),
      ]),
    );
  }
}

/// La pièce `attestation_stage` satisfaite par le module Stages : on montre la
/// preuve (date d'émission, entreprise), on ne redemande rien.
class _StageLinkedTile extends StatelessWidget {
  const _StageLinkedTile({required this.stage});
  final StageAttestation stage;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (stage.issuedAt != null)
        'émise le ${stage.issuedAt!.day.toString().padLeft(2, '0')}/'
            '${stage.issuedAt!.month.toString().padLeft(2, '0')}/${stage.issuedAt!.year}',
      if (stage.companyName != null) stage.companyName!,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGreen.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_rounded, size: 18, color: kGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attestation de stage',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const SizedBox(height: 2),
              Text(
                parts.isEmpty
                    ? 'fournie par le module Stages'
                    : '${parts.join(' · ')} — via le module Stages',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ConditionalNote extends StatelessWidget {
  const _ConditionalNote({required this.piece});
  final ExamDossierPiece piece;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 14, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: piece.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary),
                ),
                TextSpan(
                  text: ' — ${piece.conditionLabel}.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ]),
            ),
          ),
        ]),
      );
}
