import 'dart:io';

// ════════════════════════════════════════════════════════════════════════════
//  LIRE UN ÉCRAN QUI EST DEVENU UN DOSSIER
//
//  Quatre écrans de ce dépôt ont été coupés en `part` : abonnements (2 652
//  lignes), utilisateurs (2 346), administrateurs (3 134), groupes (3 400).
//  Le code n'a pas disparu, il a déménagé — et c'est précisément ce qui rend
//  une sonde dangereuse : elle ne trouve plus la forme interdite, elle passe au
//  VERT, et elle atteste d'un écran qu'elle ne regarde plus.
//
//  ⚠️ LA RÈGLE, valable pour les quatre :
//    • une sonde qui garde une RÈGLE lit la bibliothèque ENTIÈRE ;
//    • une sonde qui garde un ENCHAÎNEMENT local — « ce bouton est bien à
//      l'intérieur de cette garde » — lit SA pièce, sinon la concaténation lui
//      fait comparer des positions entre deux fichiers sans rapport.
//
//  Et dans les deux cas, on refuse de répondre si le découpage a disparu :
//  mieux vaut une sonde qui tombe qu'une sonde qui ment.
// ════════════════════════════════════════════════════════════════════════════

/// Lit un fichier en normalisant les fins de ligne.
///
/// Le dépôt mélange LF et CRLF : sans ça, toute sonde multi-lignes tombe pour
/// une raison qui n'a rien à voir avec ce qu'elle garde.
String lireSource(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) {
    throw StateError('Fichier introuvable : $chemin — sonde aveugle.');
  }
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Les morceaux `.dart` d'un dossier, dans un ordre stable.
List<File> piecesDe(String dossier) {
  final d = Directory(dossier);
  if (!d.existsSync()) {
    throw StateError(
        '$dossier a disparu — le découpage a été défait sans mettre les '
        'sondes à jour.');
  }
  return d
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Toute la bibliothèque d'un écran : la coquille ET ses pièces.
///
/// [minimumPieces] est un garde-fou, pas une décoration : si quelqu'un recolle
/// l'écran ou en ampute la moitié, ces sondes doivent tomber bruyamment plutôt
/// que de continuer à approuver.
String sourceBibliotheque({
  required String coquille,
  required String dossier,
  required int minimumPieces,
}) {
  final pieces = piecesDe(dossier);
  if (pieces.length < minimumPieces) {
    throw StateError(
        'Seulement ${pieces.length} pièces dans $dossier (attendu au moins '
        '$minimumPieces) : l’écran a été recollé ou amputé.');
  }
  return [
    lireSource(coquille),
    for (final f in pieces) lireSource(f.path),
  ].join('\n');
}

/// Le nombre de lignes de chaque fichier d'une bibliothèque.
///
/// Sert à rendre la règle des 500 lignes OPPOSABLE : un découpage qui se
/// défait doit faire tomber un test, pas attendre qu'on le remarque.
Map<String, int> taillesBibliotheque({
  required String coquille,
  required String dossier,
}) =>
    {
      coquille: lireSource(coquille).split('\n').length,
      for (final f in piecesDe(dossier))
        f.path.replaceAll(r'\', '/'): lireSource(f.path).split('\n').length,
    };
