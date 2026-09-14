import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../updates/providers/update_provider.dart' show plateformeCourante;
import '../providers/releases_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COMPILER N'EST PAS PUBLIER
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  La chaîne de mise à jour est complète et fonctionne : la bannière dans
//  `app_shell`, la vérification d'empreinte, le formulaire de publication avec
//  ses vingt-deux contrôles. Et pourtant, ONZE VERSIONS CONSÉCUTIVES — 3.5.0 à
//  3.5.14, builds 28 à 48 — n'ont jamais atteint le parc. `app_releases`
//  s'arrêtait au build 27.
//
//  Pendant ces onze versions, chaque poste du pays a demandé « existe-t-il une
//  correction ? » et s'est entendu répondre « vous êtes à jour ». Ce n'était
//  pas faux au sens du code : c'était faux au sens du produit.
//
//  ── POURQUOI ÇA NE POUVAIT PAS SE VOIR ────────────────────────────────────
//  Publier est une ÉTAPE HUMAINE qui suit la compilation, et rien nulle part ne
//  comparait les deux. `ParcSection` dit ce que le parc exécute ; la liste dit
//  ce qui est publié. Aucun des deux ne dit ce que la MACHINE D'EN FACE vient
//  de compiler. L'écart n'avait donc pas de domicile : il n'existait dans
//  aucune ligne, dans aucun écran, dans aucun test.
//
//  Une étape qu'on peut sauter sans que rien ne l'affiche finit par être
//  sautée — c'est le même défaut de fond que les `catch (_) {}` : le silence
//  d'un manquement le rend invisible, pas inoffensif.
//
//  ── CE QUE CET ENCART FAIT, ET CE QU'IL NE FAIT PAS ───────────────────────
//  Il compare le build de l'application QUI AFFICHE CET ÉCRAN au plus haut
//  build publié pour la même plateforme. Il ne publie rien, ne propose aucun
//  raccourci, et disparaît quand les deux coïncident.
//
//  ⚠️ IL NE PARLE QUE DE LA MACHINE OÙ IL S'AFFICHE. Un super_admin qui ouvre
//  la page depuis un poste ancien verra un écart qui n'existe pas côté
//  livraison — d'où la phrase « depuis ce poste », qui n'est pas une précaution
//  de style.
// ════════════════════════════════════════════════════════════════════════════

/// Le build de l'application en cours d'exécution, et sa plateforme.
final _versionCouranteProvider = FutureProvider<(String, int)>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return (info.version, int.tryParse(info.buildNumber) ?? 0);
});

/// « Ce poste exécute un build que le parc ne connaît pas. »
class VersionNonPubliee extends ConsumerWidget {
  const VersionNonPubliee({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courante = ref.watch(_versionCouranteProvider).valueOrNull;
    final publiees = ref.watch(releasesProvider).valueOrNull;
    if (courante == null || publiees == null) return const SizedBox.shrink();

    final (version, build) = courante;
    // Un build illisible (0) ne prouve rien : même règle que le provider de
    // mise à jour, qui se tait plutôt que de réclamer en boucle.
    if (build == 0) return const SizedBox.shrink();

    final plateforme = plateformeCourante();
    var plusHaut = 0;
    for (final r in publiees) {
      // `stable` en dur : c'est le canal que les postes interrogent. Un build
      // publié en `beta` est invisible pour eux, donc il ne comble pas l'écart.
      if (r.platform != plateforme || r.channel != 'stable') continue;
      if (r.buildNumber > plusHaut) plusHaut = r.buildNumber;
    }
    if (build <= plusHaut) return const SizedBox.shrink();

    final ecart = build - plusHaut;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.40)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.upload_file_rounded, size: 19, color: kAccent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ce poste exécute une version que le parc ne connaît pas',
                style: TextStyle(
                    color: kAccent, fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Depuis ce poste : $version (build $build). Le plus haut build '
              'publié pour « $plateforme / stable » est '
              '${plusHaut == 0 ? 'aucun' : plusHaut} — '
              '$ecart build${ecart > 1 ? 's' : ''} d\'écart. Tant que rien '
              'n\'est publié, chaque poste qui demande une mise à jour '
              's\'entend répondre qu\'il est à jour.',
              style: TextStyle(
                  color: kTextPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}
