import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  D'OÙ VIENT CE NIVEAU ?
//
//  Le référentiel affiché mélange deux choses que rien ne distinguait à l'œil :
//  le squelette national (`education_levels.group_id IS NULL`, commun au pays)
//  et les entrées que le groupe a créées pour lui. Deux entrées peuvent décrire
//  LA MÊME année — « Sixième (6e) » au national, « 6ème » chez le METP — et un
//  tarif posé sur l'une n'atteint pas les écoles rattachées à l'autre.
//
//  Le national ne porte AUCUN badge : c'est le cas ordinaire, et badger les 79
//  entrées communes noierait les 3 qui méritent l'attention.
// ════════════════════════════════════════════════════════════════════════════

/// Marque une entrée créée par le groupe lui-même.
class OrigineChip extends StatelessWidget {
  const OrigineChip({super.key, this.dense = true});

  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 8, vertical: dense ? 1 : 3),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: kNavy.withValues(alpha: 0.22)),
        ),
        child: Text(
          'votre groupe',
          style: TextStyle(
            fontSize: dense ? 10 : 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: kNavy,
          ),
        ),
      );
}
