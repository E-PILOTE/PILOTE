import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/sortie_motif.dart';
import '../../../core/widgets/admin_ui.dart';
import 'transfer_destination_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA SORTIE D'UN ÉLÈVE — transfert ou radiation, et son motif
//
//  ── POURQUOI CE DIALOGUE EST PARTAGÉ ───────────────────────────────────────
//  Il vivait dans `eleves_actions_parts.dart`, un `part of` de l'écran de la
//  liste : la fiche de l'élève, qui est une AUTRE bibliothèque, ne pouvait pas
//  l'atteindre. Faire sortir un élève depuis sa fiche aurait donc exigé de
//  réécrire ce dialogue — et deux dialogues de sortie qui divergent, ce sont
//  deux vocabulaires de motifs, donc des statistiques de déperdition qu'on ne
//  sait plus additionner.
//
//  ── LES DEUX EXIGENCES, ET POURQUOI ELLES NE SONT PAS DES RIGIDITÉS ────────
//  ⚠️ SANS MOTIF, PAS DE SORTIE. Une sortie sans catégorie est une ligne de
//  plus dans un total qu'on ne sait pas ventiler, et la déperdition scolaire
//  ne se lit nulle part ailleurs que dans ces motifs.
//
//  ⚠️ SANS DESTINATION, PAS DE TRANSFERT. Le texte du dialogue promet que
//  « le transfert est inscrit au registre ». La destination était pourtant
//  facultative, et sans elle aucune ligne n'était écrite : l'élève quittait
//  l'effectif, le registre restait muet, et rien ne le disait. La promesse est
//  tenue, ou le bouton reste gris.
// ════════════════════════════════════════════════════════════════════════════

/// Résultat de la sortie : motif + (pour un transfert) école de destination
/// (cascade groupe → école). Alimente le registre des Transferts.
class SortieEleveResultat {
  const SortieEleveResultat({
    required this.motif,
    required this.reason,
    this.toSchoolId,
    this.toSchoolName,
  });

  /// Catégorie normalisée — c'est elle qui se compte.
  final String motif;

  /// Le commentaire de l'agent, pour ce que la catégorie ne dit pas.
  final String reason;
  final String? toSchoolId, toSchoolName;
}

/// Demande le motif (et la destination pour un transfert). `null` = abandonné.
Future<SortieEleveResultat?> demanderMotifSortie(
  BuildContext context, {
  required String fullName,
  required bool transfert,
}) =>
    showDialog<SortieEleveResultat>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SortieDialog(fullName: fullName, transfer: transfert),
    );

class _SortieDialog extends ConsumerStatefulWidget {
  const _SortieDialog({required this.fullName, required this.transfer});
  final String fullName;
  final bool transfer;
  @override
  ConsumerState<_SortieDialog> createState() => _SortieDialogState();
}

class _SortieDialogState extends ConsumerState<_SortieDialog> {
  final _reason = TextEditingController();
  String? _motif;

  /// ⚠️ Affectée SANS `setState` à l'origine : le bouton n'apprenait jamais
  /// qu'une destination avait été choisie. Sans cela, exiger la destination
  /// aurait laissé le bouton grisé pour toujours.
  TransferDestination? _dest;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return AdminFormDialog(
      icon: t ? Icons.exit_to_app_rounded : Icons.logout_rounded,
      title: t ? 'Transférer l\'élève' : 'Radier l\'élève',
      subtitle: widget.fullName,
      width: 460,
      submitLabel: t ? 'Transférer' : 'Radier',
      submitIcon: Icons.check_rounded,
      submitColor: kRed,
      onSubmit: _motif == null || (t && !(_dest?.isValid ?? false))
          ? null
          : () => Navigator.pop(
                context,
                SortieEleveResultat(
                  motif: _motif!,
                  reason: _reason.text.trim(),
                  toSchoolId: t ? _dest?.schoolId : null,
                  toSchoolName: t ? _dest!.schoolName : null,
                ),
              ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            t
                ? 'L\'élève quitte l\'effectif (départ vers une autre école). '
                    'L\'historique est conservé et le transfert est inscrit au '
                    'registre.'
                : 'L\'élève quitte l\'effectif (abandon / exclusion). '
                    'L\'historique est conservé.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        const SizedBox(height: 14),
        if (t) ...[
          Text('École de destination *',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          TransferDestinationPicker(onChanged: (d) => setState(() => _dest = d)),
          const SizedBox(height: 14),
        ],
        Text('Motif *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _motif,
          isExpanded: true,
          decoration: adminFilledInput('Choisir un motif'),
          style: const TextStyle(fontSize: 13.5),
          items: [
            for (final m in motifsPour(transfert: t))
              DropdownMenuItem(value: m.code, child: Text(m.label)),
          ],
          onChanged: (v) => setState(() => _motif = v),
        ),
        if (_motif != null) ...[
          const SizedBox(height: 5),
          Text(
            motifsPour(transfert: t).firstWhere((m) => m.code == _motif).hint,
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.3),
          ),
        ],
        const SizedBox(height: 12),
        Text('Précision (facultatif)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _reason,
          maxLines: 2,
          style: const TextStyle(fontSize: 13.5),
          decoration: adminFilledInput('Ce que la catégorie ne dit pas'),
        ),
      ]),
    );
  }
}
