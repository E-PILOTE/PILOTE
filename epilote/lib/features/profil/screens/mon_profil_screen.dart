import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../user/widgets/staff_account_widgets.dart' show StaffSection;
import '../providers/mon_profil_provider.dart';
import 'profil_acces.dart';
import 'profil_activite.dart';
import 'profil_identite.dart';
import 'profil_infos.dart';
import 'profil_securite.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MON PROFIL — LA page, pour les trois espaces
//
//  ── CE QU'ELLE REMPLACE (2026-09-04) ──────────────────────────────────────
//  Trois écrans qui avaient divergé : 742 lignes côté super_admin (avec une
//  carte « Sécurité » faite de constantes et un champ « mot de passe actuel »
//  que rien ne lisait), 267 côté admin_groupe (trois champs), et la page du
//  personnel — la plus complète des trois, et la seule offline-first. Aucune
//  ne permettait de déposer sa photo.
//
//  Une seule page désormais, dont le périmètre se déduit du rôle : c'est la
//  règle du projet pour tout ce qui est transverse, et « Mon profil » l'est
//  par définition — tout le monde en a un.
//
//  ── L'ORDRE DES CARTES SUIT L'USAGE ───────────────────────────────────────
//  Identité, informations, sécurité à gauche : ce qu'on vient MODIFIER.
//  Accès et activité à droite : ce qu'on vient VÉRIFIER. Sur écran étroit, la
//  colonne de gauche passe devant — on ne fait pas défiler trois cartes de
//  consultation pour atteindre le champ qu'on est venu corriger.
// ════════════════════════════════════════════════════════════════════════════

class MonProfilScreen extends ConsumerWidget {
  const MonProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Mon profil',
      child: _Corps(),
    );
  }
}

class _Corps extends ConsumerWidget {
  const _Corps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monProfilProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () =>
          const FormSkeleton(sections: 3, maxWidth: double.infinity),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(messageErreur(e),
              style: TextStyle(color: kTextMuted), textAlign: TextAlign.center),
        ),
      ),
      data: (moi) {
        if (moi == null) {
          return const AdminEmptyState(
            icon: Icons.person_off_rounded,
            title: 'Profil indisponible',
            message: 'Votre profil ne peut pas être affiché. Reconnectez-vous '
                'au réseau puis réessayez.',
          );
        }
        return _Contenu(moi: moi);
      },
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.moi});
  final MonProfil moi;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 1100;

    final gauche = <Widget>[
      StaffSection(
        title: 'Informations personnelles',
        icon: Icons.edit_note_rounded,
        child: ProfilInfos(moi: moi),
      ),
      const SizedBox(height: 24),
      StaffSection(
        title: 'Sécurité',
        icon: Icons.lock_outline_rounded,
        child: ProfilSecurite(moi: moi),
      ),
    ];

    final droite = <Widget>[
      StaffSection(
        title: 'Mon accès',
        icon: Icons.verified_user_rounded,
        child: ProfilAcces(moi: moi),
      ),
      const SizedBox(height: 24),
      const StaffSection(
        title: 'Mes dernières actions',
        icon: Icons.history_rounded,
        child: ProfilActivite(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ProfilIdentite(moi: moi),
        const SizedBox(height: 24),
        if (large)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: gauche)),
            const SizedBox(width: 22),
            Expanded(child: Column(children: droite)),
          ])
        else ...[
          ...gauche,
          const SizedBox(height: 24),
          ...droite,
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
