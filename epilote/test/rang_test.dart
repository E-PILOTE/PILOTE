import 'dart:io';

import 'package:epilote/core/utils/rang.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RANG D'UN BULLETIN
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-08-27 ────────────────────────────────────────
//  Le bulletin attribuait le rang par la POSITION dans une liste triée :
//  `rang = index + 1`. Deux élèves à 14,50 recevaient 3 et 4 — l'un devant
//  l'autre sans qu'aucune note ne les sépare, sur un document que la famille
//  garde et qu'un conseil de classe lit.
//
//  Et `List.sort` n'est pas stable en Dart : l'ordre de deux valeurs égales
//  n'est pas garanti. Le même élève pouvait être 3ᵉ sur un poste et 4ᵉ sur un
//  autre, pour le même trimestre.
//
//  Le projet appliquait DÉJÀ la bonne règle au rang d'une école dans son
//  département (« deux effectifs égaux PARTAGENT le rang »). Le bulletin, non.
// ════════════════════════════════════════════════════════════════════════════

const _kBulletins = 'lib/features/evaluation/providers/bulletins_provider.dart';
const _kPassage = 'lib/features/evaluation/providers/passage_provider.dart';

/// TOUS les fichiers qui attribuent un rang. Le 2026-08-27, le garde ne
/// regardait que le bulletin — et le rang ANNUEL du passage, celui qui décide
/// d'un redoublement, gardait la forme fautive. Un garde qui ne regarde qu'un
/// fichier ne garde qu'un fichier.
const _kTousLesRangs = <String>[_kBulletins, _kPassage];

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('Rang de compétition', () {
    test('le meilleur est premier', () {
      expect(rangDeCompetition(18, const [18, 14, 12]), 1);
    });

    test('les ex æquo PARTAGENT le rang', () {
      const classe = [14.5, 14.5, 12.0];
      expect(rangDeCompetition(14.5, classe), 1);
      expect(rangDeCompetition(12.0, classe), 3,
          reason: 'Deux premiers ex æquo, donc pas de deuxième : le suivant '
              'est troisième.');
    });

    test('trois ex æquo, et le suivant saute de trois', () {
      const classe = [16.0, 16.0, 16.0, 9.0];
      expect(rangDeCompetition(16.0, classe), 1);
      expect(rangDeCompetition(9.0, classe), 4);
    });

    test('le dernier porte le rang de l\'effectif', () {
      expect(rangDeCompetition(8, const [18, 14, 12, 8]), 4);
    });

    test('l\'ordre de la liste ne change RIEN', () {
      // C'est tout l'intérêt : aucun tri, donc aucune dépendance à sa
      // stabilité. Deux postes tombent forcément sur le même nombre.
      const a = [12.0, 14.5, 14.5, 9.0];
      const b = [9.0, 14.5, 12.0, 14.5];
      expect(rangDeCompetition(12.0, a), rangDeCompetition(12.0, b));
      expect(rangDeCompetition(14.5, a), rangDeCompetition(14.5, b));
    });

    test('une classe d\'un seul élève le met premier', () {
      expect(rangDeCompetition(3.0, const [3.0]), 1,
          reason: 'Même avec une note faible : le rang dit une position, pas '
              'un mérite.');
    });
  });

  group('Aucun rang ne se lit dans une liste triée', () {
    test('la position dans un tri n\'attribue plus de rang, nulle part', () {
      // `List.sort` n'est pas stable en Dart : deux valeurs égales sortent dans
      // un ordre non garanti. Lire le rang dans cet ordre, c'est laisser deux
      // postes classer différemment les mêmes élèves.
      final fautifs = <String>[];
      for (final chemin in _kTousLesRangs) {
        final src = _lire(chemin);
        if (RegExp(r'=\s*i\s*\+\s*1').hasMatch(src)) fautifs.add(chemin);
        if (RegExp(r'ordered\[i\]').hasMatch(src)) fautifs.add(chemin);
      }
      expect(fautifs, isEmpty,
          reason: 'Forme fautive retrouvée :\n${fautifs.join('\n')}');
    });

    test('chacun passe par le helper', () {
      for (final chemin in _kTousLesRangs) {
        expect(_lire(chemin).contains('rangDeCompetition('), isTrue,
            reason: '$chemin doit COMPTER le rang, pas le lire.');
      }
    });

    test('le rang annuel du passage décide d\'un redoublement', () {
      // Ce n'est pas un détail d'affichage : `annualAverage` → rang → verdict
      // passe/redouble/réoriente. Deux élèves à la même moyenne annuelle
      // PARTAGENT le rang.
      final src = _lire(_kPassage);
      expect(src.contains('rangDeCompetition(annual[s.enrollmentId]!, values)'),
          isTrue);
    });
  });

  group('L\'ordinal français', () {
    test('le premier ne se dit pas « 1e »', () {
      expect(rangOrdinal(1), '1ᵉʳ');
      expect(rangOrdinal(2), '2ᵉ');
      expect(rangOrdinal(12), '12ᵉ');
    });

    test('un élève non classé n\'est pas « 0e »', () {
      expect(rangOrdinal(0), '—');
      expect(rangOrdinal(-1), '—');
    });

    test('plus personne ne recompose l\'ordinal à la main', () {
      // La forme fautive : une interpolation suivie du seul exposant « e », qui
      // écrit « 1e » pour le premier. On ignore les commentaires : les en-têtes
      // de correctifs citent la faute pour l'expliquer.
      final fautifs = <String>[];
      for (final f in _dartsSous('lib')) {
        final chemin = f.path.replaceAll(r'\', '/');
        if (chemin.endsWith('core/utils/rang.dart')) continue;
        final code = f
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (code.contains('}ᵉ')) fautifs.add(chemin);
      }
      expect(fautifs, isEmpty,
          reason: 'Utiliser `rangOrdinal` :\n${fautifs.join('\n')}');
    });
  });

  group('Le bulletin ne lit plus un rang dans un tri', () {
    test('les deux rangs passent par le helper', () {
      final src = _lire(_kBulletins);
      expect('rangDeCompetition('.allMatches(src).length,
          greaterThanOrEqualTo(2),
          reason: 'Rang par matière ET rang général.');
      expect(RegExp(r'=\s*i\s*\+\s*1').hasMatch(src), isFalse,
          reason: 'La position dans une liste triée ne fait pas un rang.');
    });

    test('un élève sans aucune note n\'est pas classé', () {
      // Il n'est pas dernier : il n'est pas classé. Le compter parmi les
      // autres ferait reculer toute la classe d'un cran, et l'accuserait d'un
      // résultat qu'il n'a pas eu.
      final src = _lire(_kBulletins);
      expect(src.contains('if (t.\$2 != null) t.\$1: rangDeCompetition'), isTrue);
    });
  });
}
