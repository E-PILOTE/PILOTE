import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/ine.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ⚠️ Ces tests gardent l'ALIGNEMENT avec la migration 0080 (`luhn_cle`).
//  Un INE que le serveur émet et que l'application rejette produit, au guichet,
//  un « numéro invalide » sur un numéro parfaitement valide — et personne ne
//  saura d'où il vient.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('luhnKey — conformité à l\'algorithme', () {
    test('vecteur de référence 7992739871 → 3', () {
      // Le vecteur canonique de Luhn, celui qu'on retrouve partout. La base
      // renvoie 3 elle aussi : vérifié en SQL le 2026-08-03.
      expect(luhnKey('7992739871'), 3);
    });

    test('refuse ce qui n\'est pas un chiffre', () {
      expect(() => luhnKey('26-0000012'), throwsArgumentError);
    });
  });

  group('isValidIne', () {
    // Émis par la base pendant la recette de la migration 0080.
    const emisParLaBase = '26000000013';

    test('accepte un identifiant réellement émis', () {
      expect(isValidIne(emisParLaBase), isTrue);
    });

    test('accepte la forme affichée, tirets compris', () {
      // L'agent recopie ce qu'il a sous les yeux : « 26-00000001-3 ».
      expect(isValidIne('26-00000001-3'), isTrue);
    });

    test('rejette un chiffre mal recopié', () {
      expect(isValidIne('26000000014'), isFalse);
    });

    test('rejette deux chiffres voisins inversés', () {
      // C'est la faute que Luhn attrape le mieux, et celle qu'on redoute :
      // sans clé, elle désignerait silencieusement un autre enfant.
      expect(isValidIne('26000000103'), isFalse);
    });

    test('rejette une longueur fausse', () {
      expect(isValidIne('2600000001'), isFalse);
      expect(isValidIne('260000000133'), isFalse);
    });

    test('rejette le vide et le nul', () {
      expect(isValidIne(null), isFalse);
      expect(isValidIne(''), isFalse);
      expect(isValidIne('   '), isFalse);
    });
  });

  group('formatIne', () {
    test('groupe en année · séquence · clé', () {
      expect(formatIne('26000000013'), '26-00000001-3');
    });

    test('un identifiant absent s\'affiche en tiret, pas en vide', () {
      expect(formatIne(null), '—');
    });

    test('n\'embellit pas ce qu\'il ne comprend pas', () {
      expect(formatIne('12345'), '12345');
    });

    test('reformater une forme déjà affichée est sans effet', () {
      expect(formatIne(formatIne('26000000013')), '26-00000001-3');
    });
  });
}
