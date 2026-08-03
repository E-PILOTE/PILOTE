// ════════════════════════════════════════════════════════════════════════════
//  « UNE NOUVELLE VERSION EXISTE » — discrètement, et jamais deux fois
//
//  Une bannière de mise à jour qui s'impose au milieu d'une saisie de rentrée
//  finit par être fermée sans être lue, puis par ne plus être vue du tout.
//  Celle-ci se pose en haut, se referme, et ne revient pas de la session.
//
//  L'exception est la version DÉCLARÉE OBLIGATOIRE par l'opérateur : elle ne
//  se referme pas, parce qu'elle signale que la version installée ne peut plus
//  travailler correctement (rupture de schéma). Ce n'est pas une insistance
//  commerciale, c'est un avertissement d'intégrité.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/update_provider.dart';
import 'update_dialog.dart';

/// Bannière fermée pour le reste de la session.
final _bannereMasqueeProvider = StateProvider<bool>((_) => false);

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(miseAJourProvider).valueOrNull;
    if (etat == null || !etat.enRetard) return const SizedBox.shrink();
    final release = etat.disponible!;
    final obligatoire = etat.tropAncienne;
    if (!obligatoire && ref.watch(_bannereMasqueeProvider)) {
      return const SizedBox.shrink();
    }

    final couleur = obligatoire ? kRed : kNavy;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(
            obligatoire
                ? Icons.priority_high_rounded
                : Icons.system_update_alt_rounded,
            size: 19,
            color: couleur),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              obligatoire
                  ? 'Mise à jour nécessaire — version ${release.version}'
                  : 'Version ${release.version} disponible',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: couleur),
            ),
            Text(
              obligatoire
                  ? 'La version installée (${etat.versionInstallee}) n’est plus '
                      'à jour pour fonctionner correctement.'
                  : 'Vous utilisez la version ${etat.versionInstallee}.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: () => showUpdateDialog(context, ref, etat),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Mettre à jour'),
          style: FilledButton.styleFrom(backgroundColor: couleur),
        ),
        if (!obligatoire) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Plus tard',
            icon: Icon(Icons.close_rounded, size: 18, color: kTextMuted),
            onPressed: () =>
                ref.read(_bannereMasqueeProvider.notifier).state = true,
          ),
        ],
      ]),
    );
  }
}
