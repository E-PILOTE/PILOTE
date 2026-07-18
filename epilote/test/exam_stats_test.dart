import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/models/exam_stats.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STATISTIQUES DE RÉUSSITE — le chiffre que le ministre lira.
//
//  Le piège central : calculer le taux sur l'EFFECTIF au lieu des RÉSULTATS
//  CONNUS. Une session non encore proclamée afficherait alors 0 % de réussite,
//  et une école irréprochable passerait pour sinistrée.
// ════════════════════════════════════════════════════════════════════════════

ExamStatInput _c({
  required String result,
  String? className,
  String? filiere,
  String? gender,
  String? mention,
}) =>
    ExamStatInput(
      result: result,
      className: className,
      filiereLabel: filiere,
      gender: gender,
      mention: mention,
    );

void main() {
  group('computeExamStats — le taux porte sur les résultats CONNUS', () {
    test('trois admis sur quatre résultats connus → 75 %', () {
      final s = computeExamStats([
        _c(result: 'admis'),
        _c(result: 'admis'),
        _c(result: 'admis'),
        _c(result: 'ajourne'),
      ]);
      expect(s.overall.known, 4);
      expect(s.overall.admitted, 3);
      expect(s.overall.rate, 0.75);
    });

    // Le cœur du sujet : 40 candidats, aucun résultat proclamé.
    test('aucun résultat connu → taux NUL, jamais 0 %', () {
      final s = computeExamStats([
        for (var i = 0; i < 40; i++) _c(result: 'en_attente'),
      ]);
      expect(s.overall.total, 40);
      expect(s.overall.known, 0);
      expect(s.overall.rate, isNull,
          reason: '0 % ferait passer une session non proclamée pour un échec');
    });

    test('les candidats en attente ne diluent pas le taux', () {
      final s = computeExamStats([
        _c(result: 'admis'),
        _c(result: 'admis'),
        for (var i = 0; i < 18; i++) _c(result: 'en_attente'),
      ]);
      expect(s.overall.total, 20);
      expect(s.overall.known, 2);
      expect(s.overall.rate, 1.0);
    });

    // Un absent ou un fraudeur a bien un résultat connu — il n'est pas admis.
    test('absent et fraude comptent comme résultats connus non admis', () {
      final s = computeExamStats([
        _c(result: 'admis'),
        _c(result: 'absent'),
        _c(result: 'fraude'),
      ]);
      expect(s.overall.known, 3);
      expect(s.overall.admitted, 1);
      expect(s.overall.rate, closeTo(0.3333, 0.001));
    });

    test('aucun candidat → tout à zéro, aucune division par zéro', () {
      final s = computeExamStats(const []);
      expect(s.overall.total, 0);
      expect(s.overall.known, 0);
      expect(s.overall.rate, isNull);
      expect(s.byClass, isEmpty);
    });
  });

  group('ventilations', () {
    test('par classe', () {
      final s = computeExamStats([
        _c(result: 'admis', className: '3e A'),
        _c(result: 'ajourne', className: '3e A'),
        _c(result: 'admis', className: '3e B'),
      ]);
      final a = s.byClass.firstWhere((l) => l.label == '3e A');
      final b = s.byClass.firstWhere((l) => l.label == '3e B');
      expect(a.rate, 0.5);
      expect(b.rate, 1.0);
    });

    test('par filière et par sexe', () {
      final s = computeExamStats([
        _c(result: 'admis', filiere: 'Mécanique', gender: 'M'),
        _c(result: 'ajourne', filiere: 'Mécanique', gender: 'F'),
        _c(result: 'admis', filiere: 'Comptabilité', gender: 'F'),
      ]);
      expect(s.byFiliere.length, 2);
      final f = s.byGender.firstWhere((l) => l.label == 'Filles');
      expect(f.known, 2);
      expect(f.admitted, 1);
    });

    test('les lignes ventilées sont triées par effectif décroissant', () {
      final s = computeExamStats([
        _c(result: 'admis', className: 'Petite'),
        _c(result: 'admis', className: 'Grande'),
        _c(result: 'admis', className: 'Grande'),
        _c(result: 'admis', className: 'Grande'),
      ]);
      expect(s.byClass.first.label, 'Grande');
    });

    test('une valeur absente est regroupée sous « Non renseigné »', () {
      final s = computeExamStats([_c(result: 'admis')]);
      expect(s.byClass.single.label, 'Non renseigné');
    });
  });

  group('mentions', () {
    test('comptées seulement sur les admis', () {
      final s = computeExamStats([
        _c(result: 'admis', mention: 'Bien'),
        _c(result: 'admis', mention: 'Bien'),
        _c(result: 'admis', mention: 'Passable'),
        _c(result: 'ajourne', mention: 'Bien'),
      ]);
      expect(s.mentions['Bien'], 2,
          reason: 'la mention d\'un ajourné n\'a pas de sens');
      expect(s.mentions['Passable'], 1);
    });
  });
}
