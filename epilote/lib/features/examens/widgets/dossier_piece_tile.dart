import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/dossier_piece_state.dart';
import '../models/exam_dossier_piece.dart';
import '../providers/exam_dossier_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE PIÈCE = UN EMPLACEMENT, plus une case à cocher.
//
//  La progression des couleurs dit l'état d'un coup d'œil, du plus faible au
//  plus fort : rouge (rien) → ambre (déclarée sans scan) → bleu (scan joint) →
//  vert (scan vérifié par un agent).
//
//  L'ambre n'est pas un échec : pour une chemise cartonnée ou des frais, c'est
//  l'état terminal normal. Pour une pièce dématérialisable, c'est une invitation
//  à téléverser — jamais un reproche : ces dossiers ont été cochés en toute
//  bonne foi avant que le téléversement existe.
// ════════════════════════════════════════════════════════════════════════════

const kListAmber = Color(0xFFB45309);

({Color tone, IconData icon, String label}) pieceVisual(PieceFileState s) =>
    switch (s) {
      PieceFileState.absente => (
          tone: kRed,
          icon: Icons.radio_button_unchecked_rounded,
          label: 'Manquante',
        ),
      PieceFileState.declaree => (
          tone: kListAmber,
          icon: Icons.check_circle_outline_rounded,
          label: 'Déclarée',
        ),
      PieceFileState.fournie => (
          tone: kNavy,
          icon: Icons.insert_drive_file_rounded,
          label: 'Scan joint',
        ),
      PieceFileState.verifiee => (
          tone: kGreen,
          icon: Icons.verified_rounded,
          label: 'Vérifiée',
        ),
    };

/// Les mentions qui font rejeter au comptoir quand on les ignore.
List<String> pieceTags(ExamDossierPiece p) => [
      if (p.copies > 1) '${p.copies} exemplaires',
      if (p.legalise) 'à légaliser',
      if (p.nature == PieceNature.physique) 'fourniture',
      if (p.nature == PieceNature.financiere) 'paiement',
      if (p.source == PieceSource.candidature) 'propre à cette session',
    ];

class DossierPieceTile extends StatelessWidget {
  const DossierPieceTile({
    super.key,
    required this.state,
    required this.readOnly,
    required this.busy,
    required this.onAttach,
    required this.onPreview,
    required this.onRemove,
    required this.onToggleVerify,
    required this.onToggleDeclared,
  });

  final DossierPieceState state;
  final bool readOnly;
  final bool busy;
  final VoidCallback onAttach;
  final VoidCallback onPreview;
  final VoidCallback onRemove;
  final ValueChanged<bool> onToggleVerify;
  final ValueChanged<bool> onToggleDeclared;

  bool get _isFile => state.piece.nature == PieceNature.fichier;

  @override
  Widget build(BuildContext context) {
    final v = pieceVisual(state.fileState);
    final tags = pieceTags(state.piece);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: v.tone.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: v.tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(v.icon, size: 18, color: v.tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.piece.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    tags.isEmpty ? v.label : '${v.label} · ${tags.join(' · ')}',
                    style: TextStyle(fontSize: 11, color: kTextMuted),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ]),
          if (!busy) ...[
            const SizedBox(height: 8),
            _actions(),
          ],
        ],
      ),
    );
  }

  Widget _actions() {
    // Pièce non dématérialisable : une chemise cartonnée ne sera jamais un
    // scan. La case reste le seul mode possible — elle dit enfin ce qu'elle est.
    if (!_isFile) {
      return Row(children: [
        Checkbox(
          value: state.declared,
          onChanged: readOnly ? null : (v) => onToggleDeclared(v ?? false),
          activeColor: kGreen,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            state.piece.nature == PieceNature.financiere
                ? 'Paiement effectué'
                : 'Fourniture remise',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
      ]);
    }

    final a = state.attached;
    if (a == null) {
      return Row(children: [
        if (!readOnly)
          OutlinedButton.icon(
            onPressed: onAttach,
            icon: const Icon(Icons.upload_file_rounded, size: 15),
            label: const Text('Joindre le scan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(width: 8),
        // Repli honnête : sans scanner sous la main, l'agent peut encore
        // déclarer la pièce. On ne bloque pas une école faute de matériel.
        if (!readOnly)
          TextButton(
            onPressed: () => onToggleDeclared(!state.declared),
            child: Text(
              state.declared ? 'Annuler la déclaration' : 'Déclarer sans scan',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ),
      ]);
    }

    return Wrap(spacing: 4, runSpacing: 2, children: [
      TextButton.icon(
        onPressed: onPreview,
        icon: const Icon(Icons.visibility_rounded, size: 15),
        label: const Text('Aperçu'),
        style: TextButton.styleFrom(
            foregroundColor: kNavy, visualDensity: VisualDensity.compact),
      ),
      if (!readOnly)
        TextButton.icon(
          onPressed: onAttach,
          icon: const Icon(Icons.sync_rounded, size: 15),
          label: const Text('Remplacer'),
          style: TextButton.styleFrom(
              foregroundColor: kTextMuted, visualDensity: VisualDensity.compact),
        ),
      if (!readOnly)
        TextButton.icon(
          onPressed: () => onToggleVerify(!a.isVerified),
          icon: Icon(
              a.isVerified
                  ? Icons.gpp_maybe_rounded
                  : Icons.verified_user_rounded,
              size: 15),
          label: Text(a.isVerified ? 'Retirer la vérif.' : 'Marquer vérifiée'),
          style: TextButton.styleFrom(
              foregroundColor: a.isVerified ? kTextMuted : kGreen,
              visualDensity: VisualDensity.compact),
        ),
      if (!readOnly)
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded, size: 15),
          label: const Text('Retirer'),
          style: TextButton.styleFrom(
              foregroundColor: kRed, visualDensity: VisualDensity.compact),
        ),
    ]);
  }
}
