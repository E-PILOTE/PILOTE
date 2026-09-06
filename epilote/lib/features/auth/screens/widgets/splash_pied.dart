import 'package:flutter/material.dart';

import '../../../../core/widgets/version_installee.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PIED DE L'ÉCRAN DE DÉMARRAGE — la mention institutionnelle
//
//  ── CE QUI A ÉTÉ RETIRÉ ────────────────────────────────────────────────────
//  Il disait « Agréée par le Ministère de l'Éducation · République du Congo »,
//  alors que le badge, trente pixels plus haut, disait déjà « République du
//  Congo » à côté du drapeau. Le pays était nommé deux fois sur le même écran,
//  à deux tailles différentes. La queue de la phrase est partie ; le badge
//  garde le pays, le pied garde la tutelle.
//
//  ── ⚠️ LA VERSION N'EST PLUS ÉCRITE À LA MAIN ─────────────────────────────
//  La seconde ligne affichait « v3.0 » en dur. Le paquet était en 3.5.17 : ce
//  chiffre était faux depuis seize publications, et c'était le dernier que
//  voyait un visiteur avant l'écran de connexion. Il vient maintenant de la
//  ressource de version du binaire (voir `VersionInstallee`).
// ════════════════════════════════════════════════════════════════════════════

class SplashPied extends StatelessWidget {
  const SplashPied({super.key, required this.opacity, required this.subSz});

  final Animation<double> opacity;

  /// Taille du sous-titre — le pied s'en déduit, pour rester proportionné
  /// quelle que soit la fenêtre.
  final double subSz;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Agréée par le Ministère de l'Éducation",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF4A6580),
              fontSize: subSz * 0.80,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: subSz * 0.32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MEPSA  ·  METP  ·  ',
                style: _discret(subSz),
              ),
              VersionInstallee(style: _discret(subSz)),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _discret(double subSz) => TextStyle(
        color: const Color(0xFF2E4A62),
        fontSize: subSz * 0.72,
        letterSpacing: 0.5,
      );
}
