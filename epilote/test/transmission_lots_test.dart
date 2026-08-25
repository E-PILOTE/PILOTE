import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/providers/transmission_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TRANSMISSION — découpage en LOTS (migration 0054).
//
//  Le terrain (établi par l'utilisateur, fonctionnaire à la DSIC) : la DEC
//  travaille par LOTS d'environ 50 candidats, et un lot est À L'INTÉRIEUR d'une
//  classe (la filière est portée par la classe). Ces tests verrouillent les
//  deux coutures : on ouvre un lot à chaque changement de classe, ET à chaque
//  tranche de 50 dans une même classe. Un candidat mal loti, c'est un dossier
//  qui part dans la mauvaise pile au comptoir de la DEC.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('assignLotNumbers', () {
    test('une classe sous le seuil = un seul lot', () {
      final lots = assignLotNumbers(List.filled(30, 'A'));
      expect(lots.toSet(), {1});
      expect(lots.length, 30);
    });

    test('changement de classe ouvre un nouveau lot', () {
      final lots = assignLotNumbers(['A', 'A', 'B', 'B', 'C']);
      expect(lots, [1, 1, 2, 2, 3]);
    });

    test('une classe de plus de 50 se scinde en tranches', () {
      // 120 candidats d'une même classe -> lots 1 (50), 2 (50), 3 (20).
      final lots = assignLotNumbers(List.filled(120, 'A'));
      expect(lots.first, 1);
      expect(lots[49], 1);
      expect(lots[50], 2);
      expect(lots[99], 2);
      expect(lots[100], 3);
      expect(lots.last, 3);
    });

    test('la scission ne franchit jamais une classe', () {
      // 50 en A (lot 1 plein) puis 1 en B : B ouvre le lot 2, pas la suite de A.
      final lots = assignLotNumbers([...List.filled(50, 'A'), 'B']);
      expect(lots[49], 1);
      expect(lots[50], 2);
    });

    test('liste vide -> aucun lot', () {
      expect(assignLotNumbers(const []), isEmpty);
    });

    test('classes nulles traitées comme une classe à part entière', () {
      // Un candidat sans classe ne doit pas fusionner avec le voisin.
      final lots = assignLotNumbers(['A', null, null, 'A']);
      expect(lots, [1, 2, 2, 3]);
    });
  });
}
