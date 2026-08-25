import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/examens/models/exam_stats.dart';

/// Ventilation de la réussite par FILIÈRE / DÉPARTEMENT (cockpit ministériel).
///
/// Le piège gardé ici : un taux INCONNU (rien de proclamé) ne doit JAMAIS
/// ressortir à 0 %. Une session non proclamée afficherait sinon une filière
/// irréprochable comme sinistrée — la veille d'une présentation au ministère.
void main() {
  ExamStatInput row(String result, {String? filiere, String? dept}) =>
      ExamStatInput(result: result, filiereLabel: filiere, department: dept);

  group('groupExamLines — axe filière', () {
    test('ventile et calcule le taux sur les RÉSULTATS CONNUS', () {
      final lines = groupExamLines([
        row('admis', filiere: 'Industrielle'),
        row('ajourne', filiere: 'Industrielle'),
        row('admis', filiere: 'Commerciale'),
      ], (r) => r.filiereLabel);

      final indus = lines.firstWhere((l) => l.label == 'Industrielle');
      expect(indus.total, 2);
      expect(indus.known, 2);
      expect(indus.admitted, 1);
      expect(indus.rate, 0.5);

      final com = lines.firstWhere((l) => l.label == 'Commerciale');
      expect(com.rate, 1.0);
    });

    test('taux NULL — jamais 0 % — quand rien n’est proclamé', () {
      final lines = groupExamLines([
        row('en_attente', filiere: 'Agricole'),
        row('en_attente', filiere: 'Agricole'),
      ], (r) => r.filiereLabel);

      final agri = lines.single;
      expect(agri.total, 2, reason: 'les inscrits comptent');
      expect(agri.known, 0);
      expect(agri.rate, isNull, reason: '0 % serait un mensonge : rien de proclamé');
      expect(agri.pending, 2);
    });

    test('absent et fraude sont des résultats CONNUS (non admis)', () {
      final lines = groupExamLines([
        row('admis', filiere: 'F'),
        row('absent', filiere: 'F'),
        row('fraude', filiere: 'F'),
      ], (r) => r.filiereLabel);

      expect(lines.single.known, 3);
      expect(lines.single.admitted, 1);
      expect(lines.single.rate, closeTo(1 / 3, 1e-9));
    });

    test('filière vide ou absente → « Non renseigné » (jamais perdue)', () {
      final lines = groupExamLines([
        row('admis', filiere: null),
        row('admis', filiere: '   '),
      ], (r) => r.filiereLabel);

      expect(lines.single.label, 'Non renseigné');
      expect(lines.single.total, 2);
    });
  });

  group('groupExamLines — axe département', () {
    test('même règle appliquée à la dimension territoriale', () {
      final rows = [
        row('admis', dept: 'Pool'),
        row('ajourne', dept: 'Pool'),
        row('admis', dept: 'Brazzaville'),
        row('en_attente', dept: 'Niari'),
      ];
      final lines = groupExamLines(rows, (r) => r.department);

      expect(lines.map((l) => l.label), containsAll(['Pool', 'Brazzaville', 'Niari']));
      expect(lines.firstWhere((l) => l.label == 'Pool').rate, 0.5);
      expect(lines.firstWhere((l) => l.label == 'Niari').rate, isNull);
    });

    test('tri par effectif décroissant : les grosses cohortes en tête', () {
      final lines = groupExamLines([
        row('admis', dept: 'Petit'),
        row('admis', dept: 'Gros'),
        row('admis', dept: 'Gros'),
        row('admis', dept: 'Gros'),
      ], (r) => r.department);

      expect(lines.first.label, 'Gros');
      expect(lines.last.label, 'Petit');
    });
  });

  test('isKnownExamResult — source unique partagée école ↔ ministère', () {
    for (final r in ['admis', 'ajourne', 'absent', 'fraude']) {
      expect(isKnownExamResult(r), isTrue, reason: '$r est proclamé');
    }
    expect(isKnownExamResult('en_attente'), isFalse);
  });
}
