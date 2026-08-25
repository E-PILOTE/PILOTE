import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/photo_avatar.dart' show fichierLocalEnAttente;
import '../../staff/providers/staff_photo_provider.dart' show photoAffichee;
import 'comm_text.dart' show roleColor;

// ════════════════════════════════════════════════════════════════════════════
//  Avatar utilisateur partagé : photo de profil (avatar_url) avec repli sur les
//  initiales colorées par rôle. Utilisé par la messagerie, le fil de tickets,
//  les annonces et la fiche d'un agent — un seul rendu cohérent. (Le repli
//  s'affiche aussi pendant le chargement / si l'URL est vide ou en erreur.)
//
//  ── LA PHOTO D'UN AGENT PEUT N'ÊTRE PAS ENCORE PARTIE ──────────────────────
//  Depuis la migration 0113, un chef d'établissement change la photo d'un agent
//  HORS LIGNE : les octets attendent dans `upload_outbox`, et l'URL publique
//  qu'on lui donne ici désigne un objet qui n'existe pas encore côté serveur.
//
//  Sans ce détour par le fichier local, la pastille afficherait son repli —
//  c'est-à-dire les initiales — et l'agent qui vient de choisir la photo
//  conclurait que son geste a échoué. C'est le même défaut que celui corrigé
//  côté élève, et c'est pourquoi les deux pastilles de l'application partagent
//  désormais `fichierLocalEnAttente`.
// ════════════════════════════════════════════════════════════════════════════

String avatarInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

class UserAvatarCircle extends ConsumerWidget {
  const UserAvatarCircle({
    super.key,
    this.name,
    this.role,
    this.avatarUrl,
    this.radius = 18,
    this.profileId,
  });

  final String? name;
  final String? role;
  final String? avatarUrl;
  final double  radius;

  /// L'agent représenté, quand on le connaît.
  ///
  /// Sert à une seule chose, mais elle compte : tant qu'une demande de photo
  /// n'a pas été appliquée par le serveur (migration 0113), `avatar_url` porte
  /// encore l'ANCIENNE adresse. Sans cet identifiant, la pastille montrerait
  /// donc la photo d'avant — et le chef qui vient d'en choisir une nouvelle
  /// recommencerait, croyant son geste perdu.
  ///
  /// Laissé nul, le widget se comporte exactement comme avant.
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = roleColor(role);
    final d = radius * 2;

    final fallback = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        avatarInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final id = profileId;
    final vise = id == null ? avatarUrl : photoAffichee(ref, id, avatarUrl);
    final url = vise?.trim();
    if (url == null || url.isEmpty || !url.startsWith('http')) return fallback;

    // Le fichier est encore sur le poste : on le montre plutôt que d'attendre
    // qu'il soit parti. Le repli ici serait un aveu d'échec pour un geste qui a
    // parfaitement réussi.
    final local = fichierLocalEnAttente(ref, url);
    if (local != null) {
      return ClipOval(
        child: Image.file(local,
            width: d, height: d, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: d,
        height: d,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
