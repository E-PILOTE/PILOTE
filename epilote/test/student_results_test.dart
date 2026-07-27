import 'package:epilote/features/admin_groupe/providers/student_results_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Résultats par matière du dossier de l'élève (espace ministère).
///
/// Ce qui est gardé ici n'est pas de la mise en forme : c'est ce qui décide si
/// un élève PARAÎT en échec. Une absence comptée zéro, un barème sur 40 traité
/// comme un barème sur 20, ou une matière non notée tirant la moyenne vers le
/// bas suffiraient à faire refuser une bourse à tort.
void main() {
  /// Une évaluation telle que PostgREST la renvoie.
  Map<String, dynamic> ev({
    required String subject,
    int subjectCoef = 1,
    num coefficient = 1,
    num maxScore = 20,
    required List<Map<String, dynamic>> grades,
  }) =>
      {
        'subject_id': subject,
        'coefficient': coefficient,
        'max_score': maxScore,
        'subjects': {'name': subject, 'coefficient': subjectCoef},
        'grades': grades,
      };

  Map<String, dynamic> g(String student, num? score, {bool absent = false}) =>
      {'student_id': student, 'score': score, 'is_absent': absent};

  group('Moyenne de matière', () {
    test('aucune évaluation ne produit aucune matière', () {
      expect(computeResults(const [], 'a').isEmpty, isTrue);
    });

    test('les évaluations pèsent leur propre coefficient', () {
      final r = computeResults([
        ev(subject: 'Maths', coefficient: 1, grades: [g('a', 10)]),
        ev(subject: 'Maths', coefficient: 3, grades: [g('a', 14)]),
      ], 'a');
      // (10×1 + 14×3) / 4 = 13
      expect(r.subjects.single.average, closeTo(13, 0.001));
    });

    test('une note sur un autre barème est ramenée sur 20', () {
      final r = computeResults([
        ev(subject: 'Atelier', maxScore: 40, grades: [g('a', 30)]),
      ], 'a');
      expect(r.subjects.single.average, closeTo(15, 0.001),
          reason: '30/40 vaut 15/20, pas 30');
    });

    test('une ABSENCE n\'est pas un zéro', () {
      final r = computeResults([
        ev(subject: 'Maths', grades: [g('a', 16)]),
        ev(subject: 'Maths', grades: [g('a', null, absent: true)]),
      ], 'a');
      expect(r.subjects.single.average, closeTo(16, 0.001),
          reason: 'compter l\'absence 0 donnerait 8 et un élève en échec');
      expect(r.subjects.single.gradeCount, 1);
    });

    test('une matière sans note de l\'élève reste listée, sans moyenne', () {
      final r = computeResults([
        ev(subject: 'Droit', grades: [g('autre', 12)]),
      ], 'a');
      expect(r.subjects.single.average, isNull,
          reason: 'jamais 0 : la matière est « non évaluée »');
      expect(r.subjects.single.classAverage, closeTo(12, 0.001));
    });

    test('les matières sont ordonnées alphabétiquement', () {
      final r = computeResults([
        ev(subject: 'Topographie', grades: [g('a', 10)]),
        ev(subject: 'Anglais', grades: [g('a', 10)]),
      ], 'a');
      expect(r.subjects.map((s) => s.subject), ['Anglais', 'Topographie']);
    });
  });

  group('Moyenne de la classe', () {
    test('porte sur tous les élèves, pas seulement celui consulté', () {
      final r = computeResults([
        ev(subject: 'Maths', grades: [g('a', 18), g('b', 10), g('c', 8)]),
      ], 'a');
      final s = r.subjects.single;
      expect(s.average, closeTo(18, 0.001));
      expect(s.classAverage, closeTo(12, 0.001));
      expect(s.delta, closeTo(6, 0.001), reason: 'l\'élève est au-dessus');
    });

    test('les absences des autres ne pèsent pas non plus', () {
      final r = computeResults([
        ev(subject: 'Maths', grades: [
          g('a', 12),
          g('b', null, absent: true),
        ]),
      ], 'a');
      expect(r.subjects.single.classAverage, closeTo(12, 0.001));
    });
  });

  group('Moyenne générale', () {
    test('chaque matière pèse son coefficient', () {
      final r = computeResults([
        ev(subject: 'Atelier', subjectCoef: 5, grades: [g('a', 16)]),
        ev(subject: 'EPS', subjectCoef: 1, grades: [g('a', 10)]),
      ], 'a');
      // (16×5 + 10×1) / 6 = 15
      expect(r.overall, closeTo(15, 0.001));
    });

    test('une matière non évaluée ne tire pas la moyenne vers le bas', () {
      final r = computeResults([
        ev(subject: 'Maths', subjectCoef: 4, grades: [g('a', 15)]),
        ev(subject: 'Droit', subjectCoef: 4, grades: [g('autre', 9)]),
      ], 'a');
      expect(r.overall, closeTo(15, 0.001),
          reason: 'la matière sans note de l\'élève est ignorée, pas comptée 0');
      expect(r.subjects.length, 2, reason: 'elle reste visible au tableau');
      expect(r.evaluatedCount, 1);
    });

    test('sans aucune note, la moyenne générale est absente — jamais 0', () {
      final r = computeResults([
        ev(subject: 'Maths', grades: [g('autre', 9)]),
      ], 'a');
      expect(r.overall, isNull);
    });

    test('un coefficient nul ou négatif est ramené à 1', () {
      final r = computeResults([
        ev(subject: 'Maths', subjectCoef: 0, grades: [g('a', 10)]),
        ev(subject: 'EPS', subjectCoef: 0, grades: [g('a', 14)]),
      ], 'a');
      expect(r.overall, closeTo(12, 0.001),
          reason: 'un coefficient 0 annulerait toute la matière');
    });
  });

  group('Données douteuses', () {
    test('un barème à zéro est ignoré au lieu de diviser par zéro', () {
      final r = computeResults([
        ev(subject: 'Maths', maxScore: 0, grades: [g('a', 10)]),
      ], 'a');
      expect(r.isEmpty, isTrue);
    });

    test('une matière sans nom est ignorée', () {
      final r = computeResults([
        {
          'coefficient': 1,
          'max_score': 20,
          'subjects': {'name': '   ', 'coefficient': 1},
          'grades': [g('a', 10)],
        },
      ], 'a');
      expect(r.isEmpty, isTrue);
    });

    test('une note nulle sans marqueur d\'absence est ignorée', () {
      final r = computeResults([
        ev(subject: 'Maths', grades: [g('a', null)]),
      ], 'a');
      expect(r.subjects.single.average, isNull);
    });
  });
}
