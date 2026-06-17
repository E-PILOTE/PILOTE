import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'comm_text.dart' show roleColor;

// ════════════════════════════════════════════════════════════════════════════
//  Avatar utilisateur partagé : photo de profil (avatar_url) avec repli sur les
//  initiales colorées par rôle. Utilisé par la messagerie, le fil de tickets et
//  les annonces — un seul rendu cohérent. (Le repli s'affiche aussi pendant le
//  chargement / si l'URL est vide ou en erreur.)
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

class UserAvatarCircle extends StatelessWidget {
  const UserAvatarCircle({
    super.key,
    this.name,
    this.role,
    this.avatarUrl,
    this.radius = 18,
  });

  final String? name;
  final String? role;
  final String? avatarUrl;
  final double  radius;

  @override
  Widget build(BuildContext context) {
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

    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty || !url.startsWith('http')) return fallback;

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
