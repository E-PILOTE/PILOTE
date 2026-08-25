import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/powersync/avatar_upload.dart';
import '../../services/powersync/upload_outbox.dart';
import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PASTILLE D'UNE PERSONNE — photo si elle existe, initiales sinon.
//
//  ── POURQUOI UN WIDGET PARTAGÉ ─────────────────────────────────────────────
//  Il en existait quatre copies privées, une par écran. Tant qu'elles ne
//  faisaient qu'afficher une URL, la duplication ne coûtait qu'elle-même.
//
//  Depuis que la photo se prend HORS LIGNE, elle coûte davantage : entre le
//  moment où l'agent la choisit et le retour du réseau, l'URL publique pointe
//  sur un objet qui n'existe pas encore. Une copie qui l'ignore affiche un
//  avatar cassé — et l'agent conclut que son geste a échoué, alors que la photo
//  est sur le disque, en file d'envoi.
//
//  ── POURQUOI LA FILE SE LIT EN UNE FOIS ────────────────────────────────────
//  Interroger la file par pastille ferait deux cents requêtes sur une liste de
//  personnel, et autant à chaque reconstruction. `pendingUploadPathsProvider`
//  la lit ENTIÈRE — elle est minuscule, le plus souvent vide — et chaque
//  pastille n'a plus qu'à regarder dans une carte déjà en mémoire.
// ════════════════════════════════════════════════════════════════════════════

/// Le fichier local d'une photo encore en attente, ou `null`.
///
/// Partagé par [PhotoAvatar] et `UserAvatarCircle` : les deux pastilles de
/// l'application doivent répondre pareil à la même URL.
File? fichierLocalEnAttente(WidgetRef ref, String? url) {
  final chemin = storagePathFromPublicUrl(url);
  if (chemin == null) return null;
  final enAttente = ref.watch(pendingUploadPathsProvider).valueOrNull;
  final local = enAttente?[chemin];
  if (local == null || local.isEmpty) return null;
  final f = File(local);
  return f.existsSync() ? f : null;
}

class PhotoAvatar extends ConsumerWidget {
  const PhotoAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.size,
    this.background,
    this.foreground,
  });

  /// Sert à composer les initiales quand aucune photo n'est disponible.
  final String name;

  /// URL publique. Peut désigner un fichier pas encore téléversé.
  final String? photoUrl;

  final double size;

  /// Fond de la pastille d'initiales (défaut : marine translucide).
  final Color? background;

  /// Couleur des initiales (défaut : marine). Le guichet des inscriptions
  /// teinte la pastille selon le sexe ; le registre ne le fait pas.
  final Color? foreground;

  String get _initiales {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = size / 2;

    final local = fichierLocalEnAttente(ref, photoUrl);
    if (local != null) {
      return CircleAvatar(
        radius: r,
        backgroundColor: kSurface,
        backgroundImage: FileImage(local),
      );
    }

    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: r,
        backgroundColor: kSurface,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }

    return CircleAvatar(
      radius: r,
      backgroundColor: background ?? kNavy.withValues(alpha: 0.10),
      child: Text(
        _initiales,
        style: TextStyle(
          color: foreground ?? kNavy,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
