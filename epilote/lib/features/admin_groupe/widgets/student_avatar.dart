import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  AVATAR ÉLÈVE — photo si l'établissement en a chargé une, initiales sinon.
//
//  Le repli n'est pas un pis-aller : la quasi-totalité des dossiers n'a pas de
//  photo, et une silhouette grise répétée sur toute une liste ne distingue
//  personne. Les initiales sur fond teinté, elles, se lisent d'un coup d'œil.
//  La teinte suit le sexe — même code couleur que la pastille de la liste, pour
//  qu'un même élève se reconnaisse d'un écran à l'autre.
// ════════════════════════════════════════════════════════════════════════════
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.gender,
    this.radius = 18,
  });

  final String name;
  final String? photoUrl;
  final String? gender;
  final double radius;

  static const _female = Color(0xFF7C3AED);

  Color get _color => gender == 'F' ? _female : kNavy;

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    final fallback = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withValues(alpha: 0.13),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: _color,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: d,
        height: d,
        fit: BoxFit.cover,
        // Une photo indisponible (réseau coupé, fichier supprimé) ne doit
        // jamais laisser un trou : on retombe sur les initiales.
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
