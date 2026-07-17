import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/exam_dossier_piece.dart';
import '../providers/exam_dossier_provider.dart';
import '../providers/exam_registration_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER D'UN CANDIDAT — le pré-contrôle avant le comptoir.
//
//  Pourquoi cet écran existe : la DEC vérifie les pièces AU COMPTOIR, le 13
//  février à 17 h. Si l'école a vérifié AVANT, elle n'est pas renvoyée. C'est le
//  seul moment où c'est réparable — après la clôture (14 février, 14 h 00),
//  une pièce manquante coûte une année à l'élève.
//
//  L'école vérifie, ET la DEC vérifie : notre contrôle n'est pas redondant,
//  c'est un filet posé en amont.
// ════════════════════════════════════════════════════════════════════════════

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
  /// Codes des pièces déclarées fournies. `null` tant que le dossier n'est pas
  /// chargé — pour ne pas confondre « rien de coché » et « pas encore lu ».
  Set<String>? _provided;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(candidateDossierProvider(widget.candidateId));

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
        width: 480,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
          data: (d) {
            if (d == null) return const Text('Candidature introuvable.');
            final provided = _provided ??= {
              for (final p in d.pieces.where((p) => p.provided)) p.piece.code,
            };
            return _Body(dossier: d, provided: provided, onToggle: _toggle);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || async.valueOrNull == null ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }

  void _toggle(String code, bool value) => setState(() {
        value ? _provided!.add(code) : _provided!.remove(code);
      });

  Future<void> _save() async {
    final d = ref.read(candidateDossierProvider(widget.candidateId)).valueOrNull;
    if (d == null) return;
    setState(() => _saving = true);

    // On ne réécrit que les pièces INCONDITIONNELLES non fournies : les
    // conditionnelles n'entrent jamais dans `missing_documents`, sans quoi
    // aucun dossier de bac ne pourrait plus jamais être complet.
    final missing = [
      for (final p in d.mandatory)
        if (!_provided!.contains(p.piece.code)) p.piece,
    ];

    try {
      await updateDossier(widget.candidateId,
          missing: missing.map((p) => p.toMap()).toList());
      ref.invalidate(candidateDossierProvider(widget.candidateId));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.dossier,
    required this.provided,
    required this.onToggle,
  });

  final CandidateDossier dossier;
  final Set<String> provided;
  final void Function(String code, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final d = dossier;
    final missing =
        d.mandatory.where((p) => !provided.contains(p.piece.code)).length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Banner(missing: missing, submitted: d.isSubmitted),
          const SizedBox(height: 16),
          for (final p in d.mandatory)
            if (p.isStageLinked)
              // Satisfaite par le module Stages — la source de vérité de
              // l'attestation. Pas une case à cocher : le système le sait.
              _StageLinkedTile(stage: p.linkedStage!)
            else if (p.piece.code == kStagePieceCode)
              // Pièce de stage exigée mais aucune attestation émise dans Stages.
              _StageMissingTile(
                piece: p.piece,
                checked: provided.contains(p.piece.code),
                onChanged: (v) => onToggle(p.piece.code, v ?? false),
              )
            else
              _PieceTile(
                piece: p.piece,
                checked: provided.contains(p.piece.code),
                onChanged: (v) => onToggle(p.piece.code, v ?? false),
              ),
          if (d.conditional.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('LE CAS ÉCHÉANT',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const SizedBox(height: 6),
            // Sans case à cocher, et volontairement : nous ne savons pas qui est
            // inapte à l'EPS. Le deviner produirait un dossier faux ; la DEC
            // tranche au comptoir. On rappelle, on ne prétend pas.
            for (final p in d.conditional) _ConditionalNote(piece: p.piece),
          ],
        ],
      ),
    );
  }
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

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.piece,
    required this.checked,
    required this.onChanged,
  });

  final ExamDossierPiece piece;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (piece.copies > 1) '${piece.copies} exemplaires',
      if (piece.legalise) 'à légaliser',
      if (piece.nature == PieceNature.physique) 'fourniture',
      if (piece.nature == PieceNature.financiere) 'paiement',
    ];

    return CheckboxListTile(
      value: checked,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: kGreen,
      title: Text(piece.label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kTextPrimary)),
      subtitle: tags.isEmpty
          ? null
          : Text(tags.join(' · '),
              style: TextStyle(fontSize: 11, color: kTextMuted)),
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
      margin: const EdgeInsets.only(bottom: 6),
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

/// Pièce de stage exigée, mais aucune attestation émise dans Stages. On laisse
/// la déclaration manuelle possible (preuve papier hors module) tout en pointant
/// vers là où la pièce se produit vraiment.
class _StageMissingTile extends StatelessWidget {
  const _StageMissingTile({
    required this.piece,
    required this.checked,
    required this.onChanged,
  });
  final ExamDossierPiece piece;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PieceTile(piece: piece, checked: checked, onChanged: onChanged),
          const Padding(
            padding: EdgeInsets.only(left: 32, bottom: 8),
            child: Row(children: [
              Icon(Icons.link_off_rounded, size: 13, color: kListAmber),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aucune attestation émise dans le module Stages pour cet élève.',
                  style: TextStyle(fontSize: 11, color: kListAmber),
                ),
              ),
            ]),
          ),
        ],
      );
}

const kListAmber = Color(0xFFB45309);

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
                      fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
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
