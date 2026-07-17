import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/active_agent_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VERROUILLER ≠ DÉCONNECTER — deux actions que rien ne doit confondre.
//
//  • VERROUILLER le poste  → « je quitte mon écran ». Retour à l'écran-verrou
//    (vitrine + PIN). Plusieurs fois par jour, aucun réseau, aucun risque.
//    C'est l'action de sécurité que l'agent veut réellement en partant.
//
//  • DÉCONNECTER le poste  → « ce poste quitte l'établissement ». Détruit la
//    session Supabase de l'APPAREIL, donc son droit à travailler hors-ligne :
//    plus personne ne pourra ouvrir de session ici tant qu'internet n'est pas
//    revenu. Acte d'administration, rare, à assumer explicitement.
//
//  Avant, le gros bouton rouge de la sidebar faisait la SECONDE. Un agent qui
//  « se déconnecte proprement » un vendredi soir sans réseau bloquait toute
//  l'école jusqu'au retour d'internet. D'où ce module.
// ════════════════════════════════════════════════════════════════════════════

/// Verrouille le poste : l'agent actif est oublié, l'écran-verrou revient.
/// 100 % local — fonctionne hors-ligne, ne touche JAMAIS à la session appareil.
void lockDevice(WidgetRef ref) {
  ref.read(selectedAgentIdProvider.notifier).state = null;
  ref.read(forceAgentPickerProvider.notifier).state = true;
}

/// Déconnecte l'APPAREIL, après un avertissement explicite. Renvoie `false` si
/// l'utilisateur a renoncé.
///
/// [sharedDevice] : poste du personnel scolaire (offline-first). Pour
/// super_admin / admin_groupe, online par conception, la déconnexion est
/// anodine — on ne les inonde pas d'avertissements hors-ligne.
Future<bool> guardedSignOut(
  BuildContext context,
  WidgetRef ref, {
  required bool sharedDevice,
}) async {
  if (sharedDevice) {
    final pending = await pendingLocalWork();
    if (!context.mounted) return false;
    final ok = await _confirmDeviceLogout(context, pending);
    if (ok != true) return false;
  }

  await ref.read(authNotifierProvider.notifier).signOut();
  return true;
}

Future<bool?> _confirmDeviceLogout(BuildContext context, PendingLocalWork p) {
  final bits = <String>[
    if (p.writes > 0)
      p.writes == 1 ? '1 modification' : '${p.writes} modifications',
    if (p.files > 0) p.files == 1 ? '1 fichier' : '${p.files} fichiers',
  ];

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.link_off_rounded,
          color: kRed, size: 32),
      title: const Text('Déconnecter ce poste ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ceci ne vous déconnecte pas seulement, vous : ce poste perd son '
            'droit de travailler hors-ligne.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const _Bullet(
            icon: Icons.wifi_rounded,
            text: 'Une connexion internet sera OBLIGATOIRE pour remettre ce '
                'poste en service.',
          ),
          const _Bullet(
            icon: Icons.groups_rounded,
            text: 'Aucun autre agent ne pourra ouvrir de session ici en '
                'attendant.',
          ),
          if (bits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                '⚠️ ${bits.join(' et ')} ${p.total > 1 ? "ne sont" : "n'est"} '
                'pas encore ${p.total > 1 ? "remontés" : "remonté"} au serveur. '
                'Ce travail est conservé et repartira à votre prochaine '
                'connexion — mais il sera DÉFINITIVEMENT PERDU si un autre '
                'agent ouvre une session ici avant le retour du réseau.',
                style: const TextStyle(
                    fontSize: 12.5, height: 1.4, color: Color(0xFF991B1B)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Pour simplement quitter votre écran, utilisez « Verrouiller ».',
            style: TextStyle(
                fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Déconnecter le poste'),
        ),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ]),
      );
}
