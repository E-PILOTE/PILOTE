import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange;
import '../providers/admin_fees_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE LIGNE DE TARIF
//
//  Extraite de `admin_fees_screen.dart` : la liste est passée en `SliverList`
//  et l'écran a gagné le filtre d'état, le rétablissement et les messages
//  traduits. Un gros widget = un fichier (règle des 500 lignes).
//
//  Trois états portent une information de fond, pas une décoration :
//   • ACTIF          — le tarif s'applique dans les écoles concernées ;
//   • RETIRÉ         — conservé pour que les reçus émis restent lisibles,
//                      rétablissable d'un geste ;
//   • EXAMEN ORPHELIN — un `frais_examens` qui ne vise NI un examen
//                      (`applies_to_exam_id`, mig. 0103) NI une session : le
//                      ministère le voit, le module Examens jamais. Sans ce
//                      signal, la caisse de l'examen reste fermée en face d'un
//                      tarif qui a l'air publié.
// ════════════════════════════════════════════════════════════════════════════
class AdminFeeRow extends StatelessWidget {
  const AdminFeeRow({
    super.key,
    required this.fee,
    required this.onEdit,
    required this.onRemove,
    required this.onRestore,
  });

  final AdminFee fee;
  final VoidCallback onEdit, onRemove, onRestore;

  @override
  Widget build(BuildContext context) {
    final f = fee;
    final actif = f.isActive;
    final tone = !actif ? kTextMuted : (f.estReseau ? kNavy : kAccent);

    return Opacity(
      // Un tarif retiré doit rester lisible — c'est une pièce du dossier — mais
      // ne doit jamais se confondre avec un tarif qui s'applique.
      opacity: actif ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: actif ? kBorder : kTextMuted.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                actif ? Icons.request_quote_rounded : Icons.block_rounded,
                size: 20,
                color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        decoration: actif ? null : TextDecoration.lineThrough,
                        decorationColor: kTextMuted,
                      )),
                ),
                const SizedBox(width: 8),
                _chip(adminFeeTypeLabel(f.feeType), kNavy),
                const SizedBox(width: 6),
                _chip(f.estReseau ? 'Réseau' : (f.schoolName ?? 'Établissement'),
                    tone),
                if (!actif) ...[
                  const SizedBox(width: 6),
                  _chip('Retiré', kTextMuted),
                ],
              ]),
              const SizedBox(height: 3),
              Text(
                  // Sur un frais d'examen, l'examen visé dit bien plus que
                  // « tous les niveaux » : c'est LUI qui décide qui paie.
                  '${f.examName ?? f.levelName ?? 'Tous les niveaux'}'
                  '${f.dueDay != null ? ' · échéance le ${f.dueDay}' : ''}',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
              if (f.sourceReference != null &&
                  f.sourceReference!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(f.sourceReference!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: kTextMuted)),
                ),
              if (actif && f.examenOrphelin) ...[
                const SizedBox(height: 5),
                _alerteExamenOrphelin(),
              ],
            ]),
          ),
          Text(fmtXaf(f.amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: actif ? kGreen : kTextMuted)),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
            onSelected: (v) => switch (v) {
              'edit' => onEdit(),
              'restore' => onRestore(),
              _ => onRemove(),
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ])),
              if (actif)
                PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.block_rounded, size: 16, color: kRed),
                      const SizedBox(width: 8),
                      Text('Retirer', style: TextStyle(color: kRed)),
                    ]))
              else
                PopupMenuItem(
                    value: 'restore',
                    child: Row(children: [
                      Icon(Icons.restart_alt_rounded, size: 16, color: kGreen),
                      const SizedBox(width: 8),
                      Text('Rétablir', style: TextStyle(color: kGreen)),
                    ])),
            ],
          ),
        ]),
      ),
    );
  }

  /// Dit ce qui manque ET où le corriger. L'ancien message nommait la panne
  /// (« aucune session rattachée ») sans nommer le geste, et renvoyait vers un
  /// écran de session où le rattachement n'a jamais été fait une seule fois.
  Widget _alerteExamenOrphelin() => const Row(children: [
        Icon(Icons.warning_amber_rounded, size: 13, color: kListOrange),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            'Aucun examen visé : le module Examens ne verra pas ce tarif et la '
            'caisse restera fermée. Modifiez la ligne pour choisir l\'examen.',
            style: TextStyle(
                fontSize: 11, color: kListOrange, fontWeight: FontWeight.w600),
          ),
        ),
      ]);

  Widget _chip(String label, Color tone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
      );
}
