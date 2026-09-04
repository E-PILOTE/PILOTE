import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../../communication/widgets/user_avatar.dart' show avatarInitials;

// ════════════════════════════════════════════════════════════════════════════
//  LE CHAMP PHOTO DU FORMULAIRE UTILISATEUR
//
//  Un aperçu qui répond TOUT DE SUITE, avant tout envoi : sur une connexion
//  congolaise, un écran qui ne montre rien après le clic fait recliquer, et
//  l'on se retrouve à choisir trois fois le même fichier.
//
//  L'ordre d'affichage suit l'intention de la personne, pas l'état du serveur :
//  ce qu'elle vient de choisir passe devant ce qui est enregistré, et une
//  demande de retrait passe devant les deux. Sinon, retirer une photo la
//  laisserait affichée jusqu'à l'enregistrement — et l'on cliquerait encore.
// ════════════════════════════════════════════════════════════════════════════

class ChampPhotoAgent extends StatelessWidget {
  const ChampPhotoAgent({
    super.key,
    required this.nom,
    required this.octets,
    required this.urlExistante,
    required this.retiree,
    required this.actif,
    required this.onChoisir,
    required this.onRetirer,
  });

  /// Nom affiché — sert aux initiales quand il n'y a aucune image.
  final String nom;

  /// Ce que la personne vient de choisir, pas encore envoyé.
  final Uint8List? octets;

  /// Ce que porte la fiche aujourd'hui.
  final String? urlExistante;

  /// Retrait demandé mais pas encore enregistré.
  final bool retiree;

  final bool actif;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  bool get _aQuelqueChose =>
      octets != null || (!retiree && (urlExistante?.startsWith('http') ?? false));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Pastille(
          nom: nom,
          octets: octets,
          urlExistante: retiree ? null : urlExistante),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Photo de la personne',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 3),
          Text(
            // Dire à quoi elle sert : c'est ce qui décide un secrétariat
            // pressé à prendre la photo maintenant plutôt que « plus tard ».
            'Affichée dans l\'annuaire, la messagerie et l\'écran d\'ouverture '
            'de session des postes partagés, où l\'agent choisit son visage.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: actif ? onChoisir : null,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: Text(_aQuelqueChose ? 'Changer' : 'Ajouter une photo',
                  style: const TextStyle(fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
              ),
            ),
            if (_aQuelqueChose)
              TextButton.icon(
                onPressed: actif ? onRetirer : null,
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Retirer', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(foregroundColor: kRed),
              ),
          ]),
        ]),
      ),
    ]);
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.nom,
    required this.octets,
    required this.urlExistante,
  });

  final String nom;
  final Uint8List? octets;
  final String? urlExistante;

  @override
  Widget build(BuildContext context) {
    const taille = 76.0;
    final initiales = Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      color: kNavy.withValues(alpha: 0.10),
      child: Text(
        avatarInitials(nom.trim().isEmpty ? null : nom),
        style: TextStyle(
            color: kNavy, fontSize: 24, fontWeight: FontWeight.w800),
      ),
    );

    Widget dedans = initiales;
    final url = urlExistante;
    if (octets != null) {
      dedans = Image.memory(octets!,
          width: taille, height: taille, fit: BoxFit.cover);
    } else if (url != null && url.startsWith('http')) {
      dedans = CachedNetworkImage(
        imageUrl: url,
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        placeholder: (_, _) => initiales,
        errorWidget: (_, _, _) => initiales,
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: dedans,
    );
  }
}
