// L'exclusion définitive manquait au vocabulaire : une école qui renvoyait un
// élève pour de bon n'avait aucun mot pour le dire, et son inscription restait
// ouverte. Ces tests gardent la distinction entre les deux exclusions — la
// confondre ferme l'inscription d'un enfant qui revient lundi, ou laisse
// ouverte celle d'un enfant qui ne reviendra jamais.

import 'package:epilote/core/utils/discipline_vocab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vocabulaire des sanctions', () {
    test('l\'exclusion définitive existe', () {
      expect(kSanctions.any((s) => s.$1 == 'exclusion_definitive'), isTrue);
      expect(sanctionLabel('exclusion_definitive'), 'Exclusion définitive');
    });

    test('les codes sont uniques', () {
      final codes = kSanctions.map((s) => s.$1).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('un code inconnu se rend tel quel plutôt que disparaître', () {
      expect(sanctionLabel('sanction_future'), 'sanction_future');
      expect(sanctionLabel(null), '—');
      expect(sanctionLabel(''), '—');
    });
  });

  group('Fin de scolarité', () {
    test('seule l\'exclusion DÉFINITIVE met fin à la scolarité', () {
      expect(sanctionMetFinALaScolarite('exclusion_definitive'), isTrue);
    });

    test('l\'exclusion temporaire ne ferme rien', () {
      // L'élève revient dans quelques jours : lui fermer son inscription le
      // sortirait de sa classe, de ses notes et de son emploi du temps.
      expect(sanctionMetFinALaScolarite('exclusion_temporaire'), isFalse);
      expect(sanctionMetFinALaScolarite('exclusion_cours'), isFalse);
    });

    test('le conseil de discipline ne préjuge de rien', () {
      // Le convoquer n'est pas une décision — c'est une instance qui va
      // décider. La proposer comme fin de scolarité serait décider à sa place.
      expect(sanctionMetFinALaScolarite('conseil_discipline'), isFalse);
    });

    test('aucune autre sanction, ni l\'absence de sanction', () {
      for (final s in kSanctions.where((s) => s.$1 != 'exclusion_definitive')) {
        expect(sanctionMetFinALaScolarite(s.$1), isFalse,
            reason: '${s.$2} ne doit pas fermer une inscription');
      }
      expect(sanctionMetFinALaScolarite(null), isFalse);
    });
  });
}
