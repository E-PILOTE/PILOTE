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

/// Version seule, sans le numéro de compilation : « 3.5.17 ».
///
/// Pour les endroits où la version est une SIGNATURE et non un diagnostic —
/// le pied de l'écran de démarrage, celui de la connexion. Le support, lui,
/// veut le build : il lit [appVersionProvider].
///
/// ⚠️ Ces deux écrans affichaient « v3.0 » ÉCRIT EN DUR. Le paquet était en
/// 3.5.17 : la première chose que voyait un visiteur était un chiffre faux, et
/// il l'est resté à travers seize publications. `app_constants.dart` avait déjà
/// retiré une constante `appVersion` figée pour cette raison exacte — « ne rien
/// laisser qu'un lecteur puisse croire vrai ». Un numéro de version ne
/// s'écrit pas à la main : il se lit dans le binaire.
final appVersionCourteProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  return (await PackageInfo.fromPlatform()).version;
});
