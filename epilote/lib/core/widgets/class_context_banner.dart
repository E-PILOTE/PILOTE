import 'package:flutter/material.dart';

import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BANDEAU DE CONTEXTE (classe verrouillée) — partagé par les formulaires
//  ouverts DEPUIS une classe (évaluation, créneau EDT, cahier de textes…).
//
//  Principe ERP : quand la classe est déterminée par le contexte d'ouverture,
//  on ne la REDEMANDE pas (menu ou cascade redondants, source d'erreur) : on
//  l'AFFICHE — fil Cycle ▸ Niveau ▸ Classe — en lecture seule. Lisibilité de la
//  structure sans clic, et impossible de viser la mauvaise classe.
// ════════════════════════════════════════════════════════════════════════════
class ClassContextBanner extends StatelessWidget {
  const ClassContextBanner({
    super.key,
    required this.className,
    this.cycleName,
    this.levelName,
    this.subtitle,
    this.icon = Icons.class_rounded,
  });
  final String className;
  final String? cycleName, levelName;

  /// Ligne secondaire (ex. « Trimestre : 3e trimestre »).
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final crumbs = <String>[
      if ((cycleName ?? '').isNotEmpty) cycleName!,
      if ((levelName ?? '').isNotEmpty) levelName!,
      className,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 18, color: kNavy),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(crumbs.join('  ▸  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
              ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: kNavy),
            const SizedBox(width: 4),
            Text('Contexte',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: kNavy)),
          ]),
        ),
      ]),
    );
  }
}
