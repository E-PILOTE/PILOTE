import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/providers/admin_rattachement_provider.dart';

EntreeReferentiel _e(
  String libelle, {
  required String cycle,
  required bool duGroupe,
  required int? rang,
  int ecoles = 0,
}) =>
    EntreeReferentiel(
      id: libelle,
      libelle: libelle,
      cycle: cycle,
      duGroupe: duGroupe,
      rang: rang,
      ecoles: [
        for (var i = 0; i < ecoles; i++)
          (schoolId: '$libelle-$i', schoolName: 'École $i', levelName: libelle),
      ],
    );

void main() {
  group('chercherDivergences', () {
    test('le cas réel du METP : 3 écoles au national, 1 sur l\'entrée du groupe',
        () {
      final d = chercherDivergences([
        _e('Collège · Sixième (6e)',
            cycle: 'Collège', duGroupe: false, rang: 6, ecoles: 3),
        _e('Collège · Enseignement Technique · 6ème',
            cycle: 'Collège', duGroupe: true, rang: 6, ecoles: 1),
        _e('Collège · Cinquième (5e)',
            cycle: 'Collège', duGroupe: false, rang: 5, ecoles: 3),
      ]);

      expect(d, hasLength(1));
      expect(d.single.cycle, 'Collège');
      expect(d.single.entrees, hasLength(2));
      expect(d.single.ecolesConcernees, 4);
    });

    test('deux filières nationales de même rang ne sont PAS un doublon', () {
      // « 1ère année » d'Agriculture et de BTP partagent le rang et le cycle.
      // Les signaler serait du bruit : le référentiel national les veut ainsi.
      final d = chercherDivergences([
        _e('FP · Agriculture · 1ère année',
            cycle: 'Formation Professionnelle',
            duGroupe: false,
            rang: 1,
            ecoles: 5),
        _e('FP · BTP · 1ère année',
            cycle: 'Formation Professionnelle',
            duGroupe: false,
            rang: 1,
            ecoles: 4),
      ]);

      expect(d, isEmpty);
    });

    test('un simple renommage par le groupe ne diverge pas', () {
      // L'entrée nationale n'a aucune école : personne ne se perd.
      final d = chercherDivergences([
        _e('Collège · Sixième (6e)',
            cycle: 'Collège', duGroupe: false, rang: 6, ecoles: 0),
        _e('Collège · 6ème', cycle: 'Collège', duGroupe: true, rang: 6, ecoles: 7),
      ]);

      expect(d, isEmpty);
    });

    test('un libellé sans rang lisible n\'est jamais rapproché', () {
      final d = chercherDivergences([
        _e('Collège · Section d\'adaptation',
            cycle: 'Collège', duGroupe: false, rang: null, ecoles: 2),
        _e('Collège · Classe passerelle',
            cycle: 'Collège', duGroupe: true, rang: null, ecoles: 2),
      ]);

      expect(d, isEmpty);
    });

    test('même rang mais cycles différents : rien à voir', () {
      final d = chercherDivergences([
        _e('Collège · Troisième (3e)',
            cycle: 'Collège', duGroupe: false, rang: 3, ecoles: 3),
        _e('FP · BTP · 3ème année',
            cycle: 'Formation Professionnelle',
            duGroupe: true,
            rang: 3,
            ecoles: 2),
      ]);

      expect(d, isEmpty);
    });

    test('une école des DEUX côtés est comptée une fois, et nommée', () {
      // Le cas réel : le Collège de Ouésso porte à la fois « Sixième (6e) » du
      // national et « 6ème » créée par le groupe. Additionner les branches
      // annoncerait 4 écoles là où il y en a 3.
      const ouesso = 'Collège de Ouésso';
      final d = chercherDivergences([
        const EntreeReferentiel(
          id: 'nat',
          libelle: 'Collège · Sixième (6e)',
          cycle: 'Collège',
          duGroupe: false,
          rang: 6,
          ecoles: [
            (schoolId: 'nkayi', schoolName: 'Nkayi', levelName: 'Sixième (6e)'),
            (schoolId: 'ouesso', schoolName: ouesso, levelName: 'Sixième (6e)'),
            (schoolId: 'sibiti', schoolName: 'Sibiti', levelName: 'Sixième (6e)'),
          ],
        ),
        const EntreeReferentiel(
          id: 'grp',
          libelle: 'Collège · Enseignement Technique · 6ème',
          cycle: 'Collège',
          duGroupe: true,
          rang: 6,
          ecoles: [
            (schoolId: 'ouesso', schoolName: ouesso, levelName: '6ème'),
          ],
        ),
      ]);

      expect(d, hasLength(1));
      expect(d.single.ecolesConcernees, 3, reason: 'Ouésso ne compte qu\'une fois');
      expect(d.single.ecolesDedoublees, [ouesso]);
    });

    test('les divergences les plus larges passent en tête', () {
      final d = chercherDivergences([
        _e('Collège · Sixième (6e)',
            cycle: 'Collège', duGroupe: false, rang: 6, ecoles: 1),
        _e('Collège · 6ème', cycle: 'Collège', duGroupe: true, rang: 6, ecoles: 1),
        _e('Lycée · Seconde',
            cycle: 'Lycée', duGroupe: false, rang: 2, ecoles: 9),
        _e('Lycée · 2nde', cycle: 'Lycée', duGroupe: true, rang: 2, ecoles: 6),
      ]);

      expect(d, hasLength(2));
      expect(d.first.cycle, 'Lycée');
      expect(d.first.ecolesConcernees, 15);
    });
  });
}
