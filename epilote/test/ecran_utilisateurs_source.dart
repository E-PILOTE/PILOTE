import 'dart:io';

// ════════════════════════════════════════════════════════════════════════════
//  LIRE L'ÉCRAN « UTILISATEURS » APRÈS SON DÉCOUPAGE
//
//  `admin_users_screen.dart` faisait 2 346 lignes. Il est devenu une coquille
//  de 383 lignes plus dix `part` sous `screens/users/`. Les sondes qui
//  cherchaient une forme « dans l'écran » ne trouveraient plus rien : elles
//  passeraient au VERT en ne regardant nulle part, ce qui est pire que de
//  tomber.
//
//  Ce fichier rend la bibliothèque ENTIÈRE — coquille et morceaux — et refuse
//  de répondre si le découpage a disparu. Même rôle que
//  `ecran_abonnements_source.dart` pour l'écran des abonnements.
// ════════════════════════════════════════════════════════════════════════════

const coquilleUtilisateurs =
    'lib/features/admin_groupe/screens/admin_users_screen.dart';
const dossierUtilisateurs = 'lib/features/admin_groupe/screens/users';

String _lu(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) {
    throw StateError('Fichier introuvable : $chemin — sonde aveugle.');
  }
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Toute la bibliothèque de l'écran « utilisateurs », d'un seul tenant.
String sourceEcranUtilisateurs() {
  final dossier = Directory(dossierUtilisateurs);
  if (!dossier.existsSync()) {
    throw StateError('Dossier introuvable : $dossierUtilisateurs.');
  }
  final pieces = dossier
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (pieces.length < 8) {
    throw StateError(
        'Seulement ${pieces.length} morceaux sous $dossierUtilisateurs : le '
        'découpage a été défait, et ces sondes ne regardent plus rien.');
  }

  return [
    _lu(coquilleUtilisateurs),
    for (final f in pieces) f.readAsStringSync().replaceAll('\r\n', '\n'),
  ].join('\n');
}

/// Un morceau précis, quand la sonde vise une responsabilité et non l'écran.
String sourcePieceUtilisateurs(String nom) => _lu('$dossierUtilisateurs/$nom');

/// Les fichiers de la bibliothèque et leur nombre de lignes.
Map<String, int> taillesEcranUtilisateurs() {
  final res = <String, int>{
    coquilleUtilisateurs: _lu(coquilleUtilisateurs).split('\n').length,
  };
  for (final f in Directory(dossierUtilisateurs)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    res[f.path.replaceAll(r'\', '/')] =
        f.readAsStringSync().replaceAll('\r\n', '\n').split('\n').length;
  }
  return res;
}
