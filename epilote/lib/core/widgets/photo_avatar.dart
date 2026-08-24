import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/powersync/avatar_upload.dart';
import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PASTILLE D'UNE PERSONNE — photo si elle existe, initiales sinon.
//
//  ── POURQUOI UN WIDGET PARTAGÉ ─────────────────────────────────────────────
//  Il en existait quatre copies privées, une par écran (`_Avatar` dans la liste
//  des élèves, dans celle des inscriptions, dans la messagerie, dans le pavé de
//  code agent). Tant qu'elles ne faisaient qu'afficher une URL, la duplication
//  ne coûtait qu'elle-même.
//
//  Depuis que la photo se prend HORS LIGNE, elle coûte davantage : entre le
//  moment où l'agent la choisit et le retour du réseau, l'URL publique pointe
//  sur un objet qui n'existe pas encore. Une copie qui l'ignore affiche un
//  avatar cassé — et l'agent conclut que son geste a échoué, alors que la photo
//  est sur le disque, en file d'envoi.
//
//  La règle vit donc à un seul endroit : fichier local tant qu'il attend, URL
//  ensuite, initiales si rien.
// ════════════════════════════════════════════════════════════════════════════
class PhotoAvatar extends StatefulWidget {
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

  @override
  State<PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<PhotoAvatar> {
  File? _local;

  @override
  void initState() {
    super.initState();
    _chercherLocal();
  }

  @override
  void didUpdateWidget(PhotoAvatar old) {
    super.didUpdateWidget(old);
    if (old.photoUrl != widget.photoUrl) {
      _local = null;
      _chercherLocal();
    }
  }

  /// La file d'envoi est une table locale : la consulter est bon marché, mais
  /// pas synchrone. Tant qu'on ne sait pas, on affiche l'URL — au pire une
  /// pastille vide pendant une frame, jamais une erreur.
  Future<void> _chercherLocal() async {
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) return;
    final f = await pendingFileForPublicUrl(url);
    if (mounted && f != null) setState(() => _local = f);
  }

  String get _initiales {
    final parts = widget.name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    final local = _local;
    if (local != null) {
      return CircleAvatar(
        radius: r,
        backgroundColor: kSurface,
        backgroundImage: FileImage(local),
      );
    }
    final url = widget.photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: r,
        backgroundColor: kSurface,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: r,
      backgroundColor: widget.background ?? kNavy.withValues(alpha: 0.10),
      child: Text(
        _initiales,
        style: TextStyle(
          color: widget.foreground ?? kNavy,
          fontSize: widget.size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
