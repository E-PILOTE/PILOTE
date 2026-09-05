import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/identite_etablissement.dart';
import '../admin_ui.dart' show kNavyDeep, kGreen;
import 'app_shell_theme.dart';

/// En-tête de la barre latérale : l'emblème et le nom de l'ÉTABLISSEMENT de la
/// personne connectée — son école, ou son groupe pour qui l'administre.
///
/// L'application y affichait sa propre marque à tout le monde. La règle et ses
/// raisons vivent dans [identiteEtablissementProvider] ; ce fichier ne fait que
/// la peindre.
class SidebarHeader extends ConsumerWidget {
  const SidebarHeader({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identite = ref.watch(identiteEtablissementProvider);
    final taille = expanded ? 42.0 : 36.0;

    return Tooltip(
      message: identite.sousTitre == null
          ? identite.nom
          : '${identite.nom}\n${identite.sousTitre}',
      child: Container(
        height: kShellHeaderHeight,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10),
        decoration: BoxDecoration(
          color: kNavyDeep,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            _Embleme(identite: identite, taille: taille),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identite.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (identite.sousTitre != null)
                      Text(
                        identite.sousTitre!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// L'emblème : le logo du logiciel pour la plateforme, sinon celui de
/// l'établissement, sinon ses initiales.
class _Embleme extends StatelessWidget {
  const _Embleme({required this.identite, required this.taille});
  final IdentiteEtablissement identite;
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (identite.estLaPlateforme) {
      return SvgPicture.asset('assets/icons/logo.svg',
          width: taille, height: taille);
    }

    // Le logo d'une école est presque toujours dessiné pour du papier blanc :
    // posé tel quel sur le bleu nuit de la barre, un emblème à traits sombres
    // disparaît. Le fond blanc n'est donc pas une décoration, c'est ce qui rend
    // l'image lisible — et `contain` garde l'emblème entier plutôt que d'en
    // rogner les bords.
    final initiales = Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      color: Colors.white.withValues(alpha: 0.14),
      child: Text(
        initialesEtablissement(identite.nom),
        style: TextStyle(
          color: Colors.white,
          fontSize: taille * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final url = identite.logoUrl;
    final Widget dedans = url == null
        ? initiales
        : CachedNetworkImage(
            imageUrl: url,
            width: taille,
            height: taille,
            // Le fond blanc n'apparaît qu'AVEC l'image : hors ligne au premier
            // affichage, un carré blanc vide se lirait comme un logo cassé,
            // alors que les initiales disent simplement « pas encore reçu ».
            imageBuilder: (_, provider) => Container(
              width: taille,
              height: taille,
              color: Colors.white,
              padding: const EdgeInsets.all(3),
              child: Image(image: provider, fit: BoxFit.contain),
            ),
            placeholder: (_, _) => initiales,
            errorWidget: (_, _, _) => initiales,
          );

    return Semantics(
      label: 'Logo de ${identite.nom}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: dedans,
      ),
    );
  }
}
