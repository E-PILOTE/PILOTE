import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_version.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « v3.5.17 » — LU DANS LE BINAIRE, JAMAIS TAPÉ
//
//  L'écran de démarrage et celui de connexion affichaient tous deux « v3.0»
//  en dur. C'est le premier et le dernier chiffre que voit un visiteur avant
//  d'entrer — un ministre, un directeur d'école, un technicien du support.
//  Il était faux de dix-sept versions.
//
//  Ce widget existe pour qu'il n'y ait plus qu'UN endroit où cette phrase se
//  fabrique. La lecture est asynchrone (`PackageInfo`) : tant qu'elle n'a pas
//  répondu, on n'affiche RIEN plutôt qu'un chiffre d'attente qu'on lirait
//  comme un vrai numéro.
// ════════════════════════════════════════════════════════════════════════════

class VersionInstallee extends ConsumerWidget {
  const VersionInstallee({super.key, required this.style, this.prefixe = 'v'});

  final TextStyle style;

  /// Ce qui précède le numéro — « v » par défaut, « version » ailleurs.
  final String prefixe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(appVersionCourteProvider).valueOrNull;
    // Espace insécable en réserve : le pied ne saute pas d'un pixel quand la
    // lecture arrive.
    return Text(v == null ? ' ' : '$prefixe$v', style: style);
  }
}
