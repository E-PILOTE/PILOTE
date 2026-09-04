import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/password_change_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffFmtDateTime;
import '../providers/mon_profil_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SÉCURITÉ — ce qui est VRAI, et rien d'autre
//
//  ── CE QUE CETTE CARTE REMPLACE (2026-09-04) ──────────────────────────────
//  L'ancienne carte « Sécurité » de l'espace super_admin affichait trois
//  lignes : « Authentification à deux facteurs — désactivée », « Alertes de
//  connexion par e-mail — activées », « Session sécurisée (HTTPS) — activée ».
//  Les trois étaient des CONSTANTES écrites dans le widget. La deuxième était
//  fausse : rien, nulle part, n'envoie d'alerte de connexion. Une page de
//  sécurité qui affirme une protection inexistante est pire qu'une page vide —
//  on s'y fie.
//
//  Ne figure donc ici que ce que l'application FAIT : changer le mot de passe,
//  fermer les autres sessions, et dire quand ce compte s'est connecté.
//
//  ── ⚠️ LE PIÈGE DU POSTE PARTAGÉ ──────────────────────────────────────────
//  La session Supabase appartient au compte qui a authentifié l'APPAREIL. Sur
//  un poste où un collègue a pris la main par code PIN, « changer mon mot de
//  passe » changerait celui de quelqu'un d'autre. Les deux actions sont donc
//  refusées, et la carte dit de qui est la session.
// ════════════════════════════════════════════════════════════════════════════

class ProfilSecurite extends ConsumerWidget {
  const ProfilSecurite({super.key, required this.moi});
  final MonProfil moi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estMoi = moi.estLeCompteAppareil;
    final enLigne = ref.watch(monProfilEnLigneProvider);

    return Column(children: [
      AdminCard(
        child: Column(children: [
          _Ligne(
            icone: Icons.lock_outline_rounded,
            titre: 'Mot de passe',
            detail: estMoi
                ? 'Le changement demande votre mot de passe actuel et une '
                    'connexion internet.'
                : 'Indisponible : la session de ce poste appartient à un autre '
                    'compte.',
            action: OutlinedButton.icon(
              onPressed: (!estMoi || !enLigne)
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => const PasswordChangeDialog()),
              icon: const Icon(Icons.lock_reset_rounded, size: 16),
              label: const Text('Changer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
          Divider(height: 24, color: kBorder),
          _Ligne(
            icone: Icons.history_rounded,
            titre: 'Dernière connexion',
            detail: staffFmtDateTime(moi.profil.lastLogin),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      if (estMoi) _ZoneSensible(moi: moi),
    ]);
  }
}

/// Fermer les sessions ouvertes ailleurs — le geste qu'on cherche quand on
/// craint qu'un compte soit resté ouvert sur un poste qu'on ne contrôle plus.
class _ZoneSensible extends ConsumerStatefulWidget {
  const _ZoneSensible({required this.moi});
  final MonProfil moi;

  @override
  ConsumerState<_ZoneSensible> createState() => _ZoneSensibleState();
}

class _ZoneSensibleState extends ConsumerState<_ZoneSensible> {
  bool _envoi = false;

  Future<void> _fermerLesSessions() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Fermer toutes les sessions ?'),
        content: const Text(
            'Vous serez déconnecté de tous les appareils, CELUI-CI COMPRIS, et '
            'devrez vous reconnecter.\n\nSur un poste d\'école synchronisé hors '
            'ligne, la reconnexion demande une connexion internet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Fermer les sessions'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _envoi = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signOut(scope: SignOutScope.global);
      // La redirection vers /login est gérée par l'écouteur d'authentification.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(messageErreur(e)), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 17, color: kRed),
            const SizedBox(width: 8),
            Text('Zone sensible',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kRed)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Ferme votre session sur tous les appareils où ce compte est '
            'ouvert — y compris celui-ci.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _envoi ? null : _fermerLesSessions,
            icon: const Icon(Icons.logout_rounded, size: 15),
            label: Text(
                _envoi ? 'Fermeture…' : 'Fermer toutes les sessions',
                style: const TextStyle(fontSize: 12.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRed,
              side: BorderSide(color: kRed),
            ),
          ),
        ]),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.titre,
    required this.detail,
    this.action,
  });
  final IconData icone;
  final String titre;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: kNavy, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(detail,
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.35)),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ]);
}
