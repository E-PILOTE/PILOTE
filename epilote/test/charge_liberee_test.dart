// Quand un agent part, la plateforme libère ce qui dit CE QUI EST et laisse
// intact ce qui dit CE QUI A ÉTÉ. Reste l'emploi du temps, qu'elle ne touche
// jamais — et dont elle doit donc PARLER : un silence se lirait « tout est
// réglé ». Ces tests gardent cette phrase.

import 'package:epilote/features/admin_groupe/providers/admin_carriere_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChargeLiberee', () {
    test('ne dit rien quand il n\'y a rien à dire', () {
      expect(const ChargeLiberee().resume, isNull);
      expect(const ChargeLiberee().rienASignaler, isTrue);
    });

    test('des disponibilités effacées seules ne méritent pas d\'alerte', () {
      // Elles n'engagent personne : ni classe orpheline, ni créneau à couvrir.
      const c = ChargeLiberee(disponibilitesEffacees: 4);
      expect(c.rienASignaler, isTrue);
      expect(c.resume, isNull);
    });

    test('les créneaux d\'emploi du temps ne sont JAMAIS tus', () {
      const c = ChargeLiberee(creneauxAReattribuer: 3);
      expect(c.resume, contains('3 créneaux'));
      expect(c.resume, contains('réattribuer'));
    });

    test('un seul créneau se dit au singulier', () {
      const c = ChargeLiberee(creneauxAReattribuer: 1);
      expect(c.resume, contains('1 créneau d\'emploi du temps reste'));
      expect(c.resume, isNot(contains('créneaux')));
    });

    test('cumule classes, cours et créneaux', () {
      const c = ChargeLiberee(
          classesLiberees: 2, coursLiberes: 5, creneauxAReattribuer: 7);
      final r = c.resume!;
      expect(r, contains('2 classes sans professeur principal'));
      expect(r, contains('5 affectations de cours'));
      expect(r, contains('7 créneaux'));
    });

    test('lit le compte rendu du serveur, y compris incomplet', () {
      final c = ChargeLiberee.fromMap(const {
        'cours_liberes': 3,
        'creneaux_a_reattribuer': 2,
        'affectation_id': 'peu-importe',
      });
      expect(c.coursLiberes, 3);
      expect(c.creneauxAReattribuer, 2);
      expect(c.classesLiberees, 0); // absent du compte rendu → zéro, pas null
    });
  });
}
