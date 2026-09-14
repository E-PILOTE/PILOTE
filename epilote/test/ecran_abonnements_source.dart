import 'dart:io';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCRAN DES ABONNEMENTS EST UN DOSSIER, PLUS UN FICHIER
//
//  ── POURQUOI CE PETIT UTILITAIRE (2026-09-04) ─────────────────────────────
//  `subscriptions_screen.dart` pesait 2 652 lignes ; la règle du projet en
//  fixe 500. Il a été coupé le long de ses coutures : style, badges, KPI,
//  filtres, tableau, cartes, formulaire, fiche, onglets, impression.
//
//  Cinq sondes lisaient CE fichier pour vérifier des règles métier — le
//  compte de connexion affiché, le revenu hors licences, le bouton d'émission
//  gardé par `estMinistere`… Toutes seraient devenues vertes-mais-aveugles :
//  le code n'a pas disparu, il a déménagé. Une sonde qui ne lirait que la
//  coquille attesterait d'un écran qu'elle ne regarde plus.
//
//  ⚠️ D'où la règle : une sonde qui garde une RÈGLE lit tout le dossier
//  (`sourceEcranAbonnements`) ; une sonde qui garde un ENCHAÎNEMENT local —
//  « ce bouton est bien à l'intérieur de cette garde » — lit sa pièce
//  (`sourcePieceAbonnements`), sinon la concaténation lui fait comparer des
//  positions entre deux fichiers.
// ════════════════════════════════════════════════════════════════════════════

const coquilleAbonnements =
    'lib/features/super_admin/screens/subscriptions_screen.dart';
const dossierAbonnements =
    'lib/features/super_admin/screens/subscriptions';

String _lu(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) {
    throw StateError('Fichier introuvable : $chemin — sonde aveugle.');
  }
  // Le dépôt mélange LF et CRLF : sans ça, toute sonde multi-lignes tombe.
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Tout le code de l'écran : la coquille ET ses pièces.
String sourceEcranAbonnements() {
  final morceaux = <String>[_lu(coquilleAbonnements)];
  final d = Directory(dossierAbonnements);
  if (!d.existsSync()) {
    throw StateError('$dossierAbonnements a disparu — le découpage a été '
        'défait sans mettre les sondes à jour.');
  }
  final pieces = d
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (pieces.length < 10) {
    throw StateError('Seulement ${pieces.length} pièces dans '
        '$dossierAbonnements : l’écran a été recollé ou amputé.');
  }
  morceaux.addAll(pieces.map((f) => _lu(f.path)));
  return morceaux.join('\n');
}

/// Une pièce précise du dossier, pour les sondes de proximité.
String sourcePieceAbonnements(String nom) => _lu('$dossierAbonnements/$nom');
