import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;
import '../../navigation/providers/module_navigation_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../user/widgets/staff_account_widgets.dart'
    show staffFmtDate, staffFmtDateTime;
import '../providers/mon_profil_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MON ACCÈS — ce que je suis, et ce que j'ai le droit d'ouvrir
//
//  ── POURQUOI CETTE CARTE ──────────────────────────────────────────────────
//  Un agent qui ne trouve pas un écran suppose une panne. Neuf fois sur dix,
//  son profil d'accès ne le lui accorde pas — information qui n'était visible
//  QUE depuis l'écran d'administration, c'est-à-dire par quelqu'un d'autre.
//  La lister ici transforme « ça ne marche pas » en « je n'y ai pas droit »,
//  qui est une phrase qu'on peut adresser à son directeur.
//
//  ── ⚠️ EN LECTURE SEULE, ET DÉFINITIVEMENT ────────────────────────────────
//  Rien ici ne se modifie. `role`, `access_profile_id`, `school_id`,
//  `group_id`, `is_active` sont GELÉS par le déclencheur 0188 sur sa propre
//  ligne : un écran qui proposerait de les changer afficherait « enregistré »
//  sur une valeur que la base a remise comme avant. Nul ne se donne le pouvoir.
// ════════════════════════════════════════════════════════════════════════════

class ProfilAcces extends ConsumerWidget {
  const ProfilAcces({super.key, required this.moi});
  final MonProfil moi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = moi.profil;
    final rattachement = ref.watch(monRattachementProvider);
    final matricule = p.employeeNumber;

    return Column(children: [
      AdminCard(
        child: AdminDetailCard([
          AdminDetailRow(Icons.shield_rounded, 'Rôle', roleLabel(p.role)),
          AdminDetailRow(
              p.isSchoolStaff
                  ? Icons.school_rounded
                  : Icons.account_balance_rounded,
              p.isSuperAdmin
                  ? 'Périmètre'
                  : (p.isAdminGroupe ? 'Groupe' : 'École'),
              rattachement ?? '—'),
          AdminDetailRow(Icons.tag_rounded, 'Matricule',
              (matricule != null && matricule.isNotEmpty) ? matricule : '—'),
          AdminDetailRow(
            Icons.circle,
            'Statut du compte',
            p.isActive ? 'Actif' : 'Désactivé',
            valueColor: p.isActive ? kGreen : kRed,
          ),
          AdminDetailRow(Icons.login_rounded, 'Dernière connexion',
              staffFmtDateTime(p.lastLogin)),
          AdminDetailRow(Icons.event_rounded, 'Membre depuis',
              staffFmtDate(p.createdAt),
              last: true),
        ]),
      ),
      if (p.isSchoolStaff) ...[
        const SizedBox(height: 14),
        _ModulesAccordes(moi: moi),
      ],
    ]);
  }
}

/// Les modules que le profil d'accès de cet agent lui ouvre RÉELLEMENT.
///
/// Croise les modules du plan de l'école (ce que l'établissement a payé) avec
/// les permissions de l'agent (ce que son profil lui accorde) : les deux sont
/// nécessaires, et c'est leur intersection qui décide de la barre latérale.
class _ModulesAccordes extends ConsumerWidget {
  const _ModulesAccordes({required this.moi});
  final MonProfil moi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(myPermissionsProvider);
    final modules = ref.watch(activeModulesProvider);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.apps_rounded, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Text('Modules qui vous sont ouverts',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Un module absent de cette liste n\'est pas en panne : votre profil '
          'd\'accès ne vous l\'accorde pas. Votre direction peut l\'ouvrir.',
          style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
        ),
        const SizedBox(height: 12),
        permissions.when(
          loading: () => _attente(),
          error: (_, _) => _rien(
              'Vos droits ne sont pas encore descendus sur ce poste.'),
          data: (perms) {
            if (perms.isEmpty) {
              // ⚠️ Distinguer « rien accordé » de « pas encore synchronisé »
              // est tout l'intérêt : les deux se ressemblent à l'écran et
              // n'appellent pas la même démarche.
              return _rien('Aucun profil d\'accès ne vous est assigné. '
                  'Signalez-le à votre direction.');
            }
            final noms = <String>[];
            final tous = modules.valueOrNull ?? const [];
            for (final m in tous) {
              final p = perms[m.slug];
              if (p != null && p.canRead) noms.add(m.name);
            }
            if (noms.isEmpty && tous.isEmpty) {
              return _rien('La liste des modules n\'est pas encore '
                  'synchronisée sur ce poste.');
            }
            if (noms.isEmpty) {
              return _rien('Votre profil d\'accès n\'ouvre aucun des modules '
                  'souscrits par l\'école.');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in noms)
                  AdminBadge(n, color: kNavy, icon: Icons.check_rounded),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget _attente() => Row(children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('Lecture de vos droits…',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      ]);

  Widget _rien(String message) => Text(message,
      style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4));
}
