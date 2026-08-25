import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/services/rang_niveau.dart';

void main() {
  group('rangDuNiveau — lire l\'année dans un libellé', () {
    test('le mot suffit', () {
      expect(rangDuNiveau('Sixième (6e)'), 6);
      expect(rangDuNiveau('Cinquième (5e)'), 5);
      expect(rangDuNiveau('Terminale'), 100);
      expect(rangDuNiveau('Seconde'), 2);
    });

    test('le chiffre suffit', () {
      expect(rangDuNiveau('6ème'), 6);
      expect(rangDuNiveau('6eme'), 6);
      expect(rangDuNiveau('1ère année'), 1);
      expect(rangDuNiveau('3ème année'), 3);
    });

    test('les accents ne changent rien', () {
      expect(rangDuNiveau('SIXIÈME'), rangDuNiveau('sixieme'));
      expect(rangDuNiveau('Première'), 1);
    });

    test('le mot l\'emporte sur un chiffre de passage', () {
      // Sans cette priorité, le « 3 » du nom de la filière ferait de cette
      // 1ère année une 3ème.
      expect(rangDuNiveau('Première année du BTP 3'), 1);
    });

    test('un nombre nu n\'est pas un rang — ne rien deviner', () {
      expect(rangDuNiveau('Groupe 3'), isNull);
      expect(rangDuNiveau('Section d\'adaptation'), isNull);
      expect(rangDuNiveau('Classe passerelle'), isNull);
      expect(rangDuNiveau(''), isNull);
    });
  });

  group('memeAnnee — le cas réel du METP', () {
    test('« Sixième (6e) » du national et « 6ème » du groupe sont la même année',
        () {
      // Trois collèges METP rattachent leur 6e au national, un quatrième à
      // l'entrée créée par le groupe. Un tarif réseau sur la 6e manquait la
      // quatrième école sans le dire.
      expect(memeAnnee('Sixième (6e)', '6ème'), isTrue);
      expect(memeAnnee('Quatrième (4e)', '4ème'), isTrue);
      expect(memeAnnee('Troisième (3e)', '3ème'), isTrue);
    });

    test('deux années différentes ne se confondent pas', () {
      expect(memeAnnee('Sixième (6e)', 'Cinquième (5e)'), isFalse);
      expect(memeAnnee('1ère année', '2ème année'), isFalse);
    });

    test('un libellé illisible ne déclenche AUCUN rapprochement', () {
      // Un faux avertissement apprend à cliquer « continuer » sans lire.
      expect(memeAnnee('Section d\'adaptation', 'Classe passerelle'), isFalse);
      expect(memeAnnee('Sixième (6e)', 'Section d\'adaptation'), isFalse);
    });
  });
}
