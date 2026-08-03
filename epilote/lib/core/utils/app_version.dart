import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA VERSION RÉELLEMENT INSTALLÉE SUR CE POSTE
//
//  Elle était écrite en dur dans l'écran des paramètres — « 3.0.2 » pour un
//  paquet en 3.1.7. Sur un parc mis à jour à la main, où chaque établissement
//  peut être sur une version différente, c'est la PREMIÈRE question du support :
//  « quelle version tourne chez vous ? » Une réponse fausse envoie chercher un
//  bug là où il n'est plus.
//
//  `package_info_plus` lit la version embarquée dans le binaire — sous Windows,
//  la ressource de version de `E-PILOTE.exe`, celle-là même qu'affiche la fiche
//  de propriétés du fichier. Impossible qu'elle diverge de ce qui est installé.
// ════════════════════════════════════════════════════════════════════════════

/// Version affichable : « 3.1.7 (build 18) ».
final appVersionProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber;
  return build.isEmpty ? info.version : '${info.version} (build $build)';
});
