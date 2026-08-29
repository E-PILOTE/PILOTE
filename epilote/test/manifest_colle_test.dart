import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COLLER LE manifest.json DANS LE FORMULAIRE DE PUBLICATION
//
//  ── LE PIÈGE ───────────────────────────────────────────────────────────────
//  `manifest.json` est produit par la CI avec `Set-Content -Encoding utf8`.
//  Sous Windows PowerShell, cet encodage pose un BOM UTF-8 (EF BB BF) en tête
//  du fichier. Ouvrir le fichier, tout sélectionner, coller dans le formulaire :
//  `jsonDecode` échoue AU CARACTÈRE 0, et son message ne parle pas de BOM.
//
//  Ce n'est pas un cas tordu : c'est le chemin normal de publication, sur le
//  fichier que notre propre CI fabrique. Celui qui publie voit « ce n'est pas
//  un manifest lisible » devant un fichier parfaitement valide, et retape à la
//  main une empreinte de 64 caractères — que l'application compare ensuite
//  octet pour octet avant d'autoriser une mise à jour sur mille postes.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que fait le formulaire avant de décoder. Doit rester identique à
/// `release_form_dialog.dart` — le garde ne vaut que par cette égalité.
String nettoyer(String colle) =>
    colle.trim().replaceFirst(RegExp('^﻿'), '');

const _kManifestReel = '''
{
    "version":  "3.4.0",
    "build_number":  22,
    "platform":  "windows",
    "channel":  "stable",
    "sha256":  "5d793120e5a236391212df19bfca66a839be7cd99b8f8e4b5d57b7c5db0d7aa6",
    "size_bytes":  35882496,
    "download_url":  "https://github.com/E-PILOTE/telechargements/releases/download/v3.4.0/E-PILOTE-3.4.0-installateur.exe"
}''';

void main() {
  group('Le BOM ne fait plus échouer la publication', () {
    test('sans nettoyage, jsonDecode refuse — c’est bien le défaut réel', () {
      expect(() => jsonDecode('﻿$_kManifestReel'), throwsFormatException,
          reason: 'Si ceci cesse d’échouer, Dart a changé et le nettoyage '
              'devient inutile — mais inoffensif.');
    });

    test('avec nettoyage, le manifeste se lit', () {
      final m = jsonDecode(nettoyer('﻿$_kManifestReel'))
          as Map<String, dynamic>;
      expect(m['version'], '3.4.0');
      expect(m['build_number'], 22);
      expect((m['sha256'] as String).length, 64);
    });

    test('un manifeste sans BOM se lit toujours', () {
      final m = jsonDecode(nettoyer(_kManifestReel)) as Map<String, dynamic>;
      expect(m['version'], '3.4.0');
    });

    test('les espaces et retours à la ligne d’un copier-coller n’arrêtent rien',
        () {
      final m = jsonDecode(nettoyer('\n\n  ﻿$_kManifestReel  \n'))
          as Map<String, dynamic>;
      expect(m['build_number'], 22);
    });

    test('du texte qui n’est pas du JSON échoue toujours, et c’est voulu', () {
      expect(() => jsonDecode(nettoyer('bonjour')), throwsFormatException);
    });
  });

  group('Le formulaire applique bien ce nettoyage', () {
    test('le décodeur ne reçoit JAMAIS le texte collé brut', () {
      // Vérifier l'ORDRE des deux mots dans le fichier serait fragile : un
      // commentaire qui nomme `jsonDecode` suffirait à le fausser (c'est
      // arrivé en écrivant ce garde). On vérifie donc la chose elle-même.
      final src = File(
        'lib/features/super_admin/screens/release_form_dialog.dart',
      ).readAsStringSync();
      expect(src.contains('jsonDecode(brut)'), isTrue,
          reason: 'Le décodage doit porter sur le texte NETTOYÉ.');
      expect(src.contains('jsonDecode(_colle.text)'), isFalse,
          reason: 'Décoder le collage brut ramène le piège du BOM sur le '
              'chemin normal de publication.');
      expect(src.contains('replaceFirst'), isTrue,
          reason: 'Le nettoyage a disparu du formulaire.');
    });
  });
}
