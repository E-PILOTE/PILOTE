import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../services/eleve_cycle_actions.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE MENU DU CYCLE DE VIE — le même depuis le tiroir et depuis la fiche
//
//  ── POURQUOI UN SEUL MENU ──────────────────────────────────────────────────
//  Deux menus qui divergent, ce sont deux écoles qui n'ont pas les mêmes
//  gestes selon l'endroit d'où l'agent est parti — et un jour, une garde
//  ajoutée d'un côté seulement.
//
//  ── L'ORDRE N'EST PAS DÉCORATIF ────────────────────────────────────────────
//  Ce qui se DÉLIVRE vient en premier (certificat, carte) : ce sont les gestes
//  quotidiens, et ils restent offerts sur une année clôturée — imprimer n'est
//  pas écrire. Ce qui MODIFIE suit. Ce qui fait SORTIR vient en dernier,
//  derrière un séparateur, parce qu'on ne radie pas un élève par glissement de
//  souris.
//
//  ⚠️ LA BARRE ENTIÈRE DISPARAISSAIT SUR UNE ANNÉE CLÔTURÉE, et elle porte le
//  certificat de scolarité. Or `yearReadOnly` est vrai dès qu'on consulte une
//  année passée — et c'est précisément pour une année passée qu'on réclame ce
//  papier : un ancien élève monte un dossier de bourse, de visa,
//  d'équivalence. La barre reste, réduite à ce qui se lit.
// ════════════════════════════════════════════════════════════════════════════

/// Le menu « Actions » du cycle de vie d'un élève.
///
/// [onApresSortie] est appelé quand l'élève vient de quitter l'effectif : le
/// tiroir s'y referme, la fiche y revient à la liste. Le service, lui, ne
/// navigue jamais.
class EleveActionsMenu extends ConsumerWidget {
  const EleveActionsMenu({
    super.key,
    required this.cible,
    required this.readOnly,
    this.onApresSortie,
    this.compact = false,
  });

  final EleveCible cible;

  /// Année clôturée ou passée : plus rien ne s'écrit, mais tout se lit — et
  /// s'imprime.
  final bool readOnly;
  final VoidCallback? onApresSortie;

  /// `true` dans l'en-tête de la fiche, où le libellé « Actions » entrerait en
  /// concurrence avec les boutons Modifier et Imprimer.
  final bool compact;

  Future<void> _lancer(BuildContext context, WidgetRef ref, String v) async {
    switch (v) {
      case 'certificat':
        await certificatScolariteEleve(context, ref, cible);
      case 'radiation':
        await certificatRadiationEleve(context, ref, cible);
      case 'carte':
        await carteScolaireEleve(context, ref, cible);
      case 'class':
        await changerClasseEleve(context, ref, cible);
      case 'revert':
        if (await annulerInscriptionEleve(context, ref, cible)) onApresSortie?.call();
      case 'transfer':
        if (await sortirEleve(context, ref, cible, status: 'transferred')) {
          onApresSortie?.call();
        }
      case 'withdraw':
        if (await sortirEleve(context, ref, cible, status: 'withdrawn')) {
          onApresSortie?.call();
        }
      case 'deactivate':
        if (await desactiverEleve(context, ref, cible)) onApresSortie?.call();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpdate =
        !readOnly && ref.watch(canProvider((slug: 'eleves', action: 'update')));
    final canDelete =
        !readOnly && ref.watch(canProvider((slug: 'eleves', action: 'delete')));

    // ⚠️ Sans inscription de l'année, les gestes qui portent sur l'ANNÉE n'ont
    // pas d'objet : `enrollmentId!` planterait. On ne les propose pas plutôt
    // que de les proposer cassés.
    final surAnnee = canUpdate && cible.aUneInscription;

    return PopupMenuButton<String>(
      tooltip: 'Cycle de vie',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 6),
      onSelected: (v) => _lancer(context, ref, v),
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'certificat',
            child: _MenuRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Certificat de scolarité')),
        // Le duplicata : un élève perd sa carte en cours d'année et se présente
        // au guichet. La fabrication de MASSE, elle, est le module « Cartes
        // scolaires » — pas ce menu.
        // ⚠️ N'APPARAÎT QUE POUR UN ÉLÈVE SORTI, et c'est tout l'objet : le
        // certificat de radiation n'existait qu'à l'instant de la sortie.
        // Passé ce moment, une famille qui revenait — bourse, inscription
        // ailleurs, équivalence — n'avait plus aucun moyen de l'obtenir.
        // Il vient AVANT la carte parce que, pour un élève parti, c'est le
        // seul des deux papiers qui ait encore un sens.
        if (peutReclamerRadiation(cible))
          const PopupMenuItem(
              value: 'radiation',
              child: _MenuRow(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Certificat de radiation')),
        const PopupMenuItem(
            value: 'carte',
            child:
                _MenuRow(icon: Icons.badge_outlined, label: 'Carte scolaire')),
        // Le séparateur ne se dessine que s'il sépare quelque chose : sur une
        // année clôturée, le certificat est seul et le trait pendait.
        if (surAnnee || canDelete) const PopupMenuDivider(),
        if (surAnnee)
          const PopupMenuItem(
              value: 'class',
              child: _MenuRow(
                  icon: Icons.swap_horiz_rounded, label: 'Changer de classe')),
        if (surAnnee)
          const PopupMenuItem(
              value: 'revert',
              child: _MenuRow(
                  icon: Icons.undo_rounded, label: 'Annuler l\'inscription')),
        if (surAnnee)
          const PopupMenuItem(
              value: 'transfer',
              child: _MenuRow(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Transférer (autre école)')),
        if (surAnnee)
          const PopupMenuItem(
              value: 'withdraw',
              child: _MenuRow(
                  icon: Icons.logout_rounded, label: 'Radier / abandon')),
        if (canDelete) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
              value: 'deactivate',
              child: _MenuRow(
                  icon: Icons.person_off_outlined,
                  label: 'Désactiver',
                  color: kRed)),
        ],
      ],
      child: compact
          ? Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Icon(Icons.more_horiz_rounded, color: kTextMuted, size: 20),
            )
          : Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.more_horiz_rounded, color: kTextMuted, size: 20),
                const SizedBox(width: 6),
                Text('Actions',
                    style: TextStyle(
                        color: kTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
    );
  }
}

/// La barre du bas du tiroir : « Modifier » et le menu du cycle de vie.
class EleveActionsBar extends ConsumerWidget {
  const EleveActionsBar({
    super.key,
    required this.cible,
    required this.readOnly,
    required this.onModifier,
    this.onApresSortie,
  });

  final EleveCible cible;
  final bool readOnly;
  final VoidCallback onModifier;
  final VoidCallback? onApresSortie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpdate =
        !readOnly && ref.watch(canProvider((slug: 'eleves', action: 'update')));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
      child: Row(children: [
        if (canUpdate)
          Expanded(
            child: AdminPrimaryButton(
              label: 'Modifier',
              icon: Icons.edit_outlined,
              color: kNavy,
              onTap: onModifier,
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 10),
        EleveActionsMenu(
            cible: cible, readOnly: readOnly, onApresSortie: onApresSortie),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? kTextPrimary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13.5,
                color: color ?? kTextPrimary,
                fontWeight: FontWeight.w600)),
      ]);
}
