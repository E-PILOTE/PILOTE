import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/mention.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MENTIONS — barème officiel du METP.
//
//  Ce barème existait en trois exemplaires (deux en Dart, un en SQL) et deux
//  d'entre eux avaient dérivé de deux points. Conséquence observée à l'écran :
//  15/20 affiché « Très Bien », et 8/20 — une note d'échec — présenté comme
//  « Passable » sur un bulletin destiné aux familles.
//
//  Ces tests fixent les SEUILS, y compris juste en dessous, parce que c'est
//  exactement là qu'une dérive d'un point se cache. Ils doivent rester le
//  source unique : `get_mention()` en base a été supprimée en 0117, faute
//  d'appelant — une règle non testée finit toujours par diverger.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('mentionFor — le barème officiel, seuil par seuil', () {
    test('Excellent à partir de 18', () {
      expect(mentionFor(20), 'Excellent');
      expect(mentionFor(18), 'Excellent');
      expect(mentionFor(17.99), isNot('Excellent'));
    });

    test('Très Bien de 16 à 18 exclus', () {
      expect(mentionFor(17.99), 'Très Bien');
      expect(mentionFor(16), 'Très Bien');
      expect(mentionFor(15.99), isNot('Très Bien'));
    });

    test('Bien de 14 à 16 exclus', () {
      expect(mentionFor(15.99), 'Bien');
      expect(mentionFor(14), 'Bien');
      // Le cas vu à l'écran avant correction : 15,00 affichait « Très Bien ».
      expect(mentionFor(15), 'Bien');
    });

    test('Assez Bien de 12 à 14 exclus', () {
      expect(mentionFor(13.99), 'Assez Bien');
      expect(mentionFor(12), 'Assez Bien');
    });

    test('Passable de 10 à 12 exclus', () {
      expect(mentionFor(11.99), 'Passable');
      expect(mentionFor(10), 'Passable');
    });

    test('sous 10, Insuffisant — jamais « Passable »', () {
      expect(mentionFor(9.99), 'Insuffisant');
      // Le défaut le plus grave de l'ancien barème : 8/20 = « Passable ».
      expect(mentionFor(8), 'Insuffisant');
      expect(mentionFor(0), 'Insuffisant');
    });

    test('sans moyenne, un tiret — pas « Insuffisant »', () {
      // Une classe dont les notes ne sont pas encore saisies ne doit pas voir
      // ses élèves accusés d'insuffisance.
      expect(mentionFor(null), '—');
    });
  });

  group('isPassing — la barre reste 10/20', () {
    test('10 passe, 9,99 ne passe pas', () {
      expect(isPassing(10), isTrue);
      expect(isPassing(9.99), isFalse);
    });

    test('sans moyenne, on ne déclare pas la réussite', () {
      expect(isPassing(null), isFalse);
    });

    test('la barre de réussite vaut 10', () {
      expect(kPassingMark, 10.0);
    });
  });
}
