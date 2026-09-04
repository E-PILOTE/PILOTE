import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../providers/subscriptions_provider.dart';
import 'subs_style.dart';

// ─── Glyphe de groupe & pastilles ──────────────────────────────────────
//  Les trois vues (tableau, cartes, fiche) montrent le MÊME groupe : même
//  logo, même statut, même type. Un badge redéclaré par vue, c'est trois
//  vérités qui divergent au premier changement de couleur.

class SubGroupGlyph extends StatelessWidget {
  const SubGroupGlyph({super.key, required this.sub, this.size = 38});
  final SubscriptionDetail sub;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = subTypeColor(sub.groupType);
    final logo = sub.groupLogo;
    if (logo != null && logo.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: CachedNetworkImage(
          imageUrl: logo,
          width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(color),
          errorWidget: (_, _, _) => _fallback(color),
        ),
      );
    }
    return _fallback(color);
  }

  Widget _fallback(Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(sub.initials, style: TextStyle(
        color: color, fontSize: size * 0.36, fontWeight: FontWeight.w800)),
  );
}

class SubStatusBadge extends StatelessWidget {
  const SubStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = subStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(subStatusIcon(status), size: 11, color: color),
        const SizedBox(width: 4),
        Text(subStatusLabel(status),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class SubTypeBadge extends StatelessWidget {
  const SubTypeBadge({super.key, required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final color = subTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(subTypeIcon(type), size: 11, color: color),
        const SizedBox(width: 4),
        Text(type == 'public' ? 'Public' : 'Privé',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class SubEmptyState extends StatelessWidget {
  const SubEmptyState({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.workspace_premium_rounded, size: 56, color: kSubBorder),
      const SizedBox(height: 16),
      Text('Aucun abonnement trouvé', style: TextStyle(
          color: kSubText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouvel abonnement.',
          style: TextStyle(color: kSubMuted, fontSize: 13)),
    ]),
  );
}
