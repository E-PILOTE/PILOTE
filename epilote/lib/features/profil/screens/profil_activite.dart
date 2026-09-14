import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../audit/providers/audit_models.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffFmtDateTime;
import '../providers/mon_activite_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MES DERNIÈRES ACTIONS
//
//  La question qu'on se pose sur son propre compte, et à laquelle aucune page
//  ne répondait : « qu'est-ce que j'ai fait la dernière fois ? » — et sa sœur,
//  plus sérieuse sur un poste partagé : « quelqu'un a-t-il agi sous mon nom ? »
//
//  ⚠️ Cette liste ne prouve rien : le journal n'enregistre que ce que les
//  déclencheurs écrivent, et le personnel n'en reçoit hors ligne que la partie
//  emploi du temps. La carte le dit — une liste vide ne veut pas dire
//  « aucune action ».
// ════════════════════════════════════════════════════════════════════════════

class ProfilActivite extends ConsumerWidget {
  const ProfilActivite({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(mesDernieresActionsProvider);
    final extrait = ref.watch(mesActionsSontUnExtraitProvider);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        actions.when(
          loading: () => _message('Lecture du journal…'),
          error: (_, _) => _message('Journal indisponible pour le moment.'),
          data: (liste) {
            if (liste.isEmpty) {
              return _message(extrait
                  ? 'Aucune action de votre part dans la partie du journal '
                      'synchronisée sur ce poste.'
                  : 'Aucune action enregistrée à votre nom pour l\'instant.');
            }
            return Column(children: [
              for (var i = 0; i < liste.length; i++) ...[
                if (i > 0) Divider(height: 18, color: kBorder),
                _LigneAction(entree: liste[i]),
              ],
            ]);
          },
        ),
        if (extrait) ...[
          const SizedBox(height: 14),
          Text(
            'Extrait : hors ligne, ce poste ne reçoit que le journal de '
            'l\'emploi du temps. Le registre complet reste au serveur.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
          ),
        ],
      ]),
    );
  }

  Widget _message(String texte) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(texte,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
      );
}

class _LigneAction extends StatelessWidget {
  const _LigneAction({required this.entree});
  final AuditEntry entree;

  Color get _couleur => switch (entree.action.toUpperCase()) {
        'DELETE' => kRed,
        'INSERT' => kGreen,
        'UPDATE' => kNavy,
        _ => kTextMuted,
      };

  IconData get _icone => switch (entree.action.toUpperCase()) {
        'DELETE' => Icons.delete_outline_rounded,
        'INSERT' => Icons.add_circle_outline_rounded,
        'UPDATE' => Icons.edit_outlined,
        _ => Icons.bolt_rounded,
      };

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icone, size: 16, color: _couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entree.actionLabel} · ${entree.entityLabel}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(staffFmtDateTime(entree.createdAt),
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ),
      ]);
}
