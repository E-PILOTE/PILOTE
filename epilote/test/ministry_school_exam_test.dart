import 'package:epilote/features/admin_groupe/providers/admin_exams_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE D'ÉTABLISSEMENT DU COCKPIT — les règles de lecture d'une ligne école.
//
//  Toutes tournent autour d'une seule idée : ne jamais présenter une absence
//  d'information comme une information. « Pas encore proclamé » n'est pas
//  « zéro admis », et « 12 candidats » ne dit pas où est le retard.
// ════════════════════════════════════════════════════════════════════════════
MinistrySchoolExam _school({
  int candidates = 0,
  int complete = 0,
  int submitted = 0,
  int withResult = 0,
  int admitted = 0,
  int transmissions = 0,
  List<SchoolExamLine> byExam = const [],
}) =>
    MinistrySchoolExam(
      schoolId: 's1',
      schoolName: 'Lycée technique de Kinkala',
      candidates: candidates,
      complete: complete,
      submitted: submitted,
      withResult: withResult,
      admitted: admitted,
      transmissions: transmissions,
      lastTransmittedAt: null,
      department: 'Pool',
      byExam: byExam,
    );

SchoolExamLine _line({
  int candidates = 0,
  int withResult = 0,
  int admitted = 0,
}) =>
    SchoolExamLine(
      examShortName: 'BET',
      candidates: candidates,
      complete: candidates,
      submitted: candidates,
      withResult: withResult,
      admitted: admitted,
    );

void main() {
  group('Réussite d\'un examen dans une école', () {
    test('aucun résultat connu → aucun taux, surtout pas 0 %', () {
      // 0 % se lirait « tous recalés » sur une session dont la DEC n'a encore
      // rien proclamé.
      expect(_line(candidates: 30).successRate, isNull);
    });

    test('le taux porte sur les résultats CONNUS, pas sur les candidats', () {
      // 6 admis sur 8 résultats connus = 75 %, même si 30 candidats étaient
      // inscrits. Diviser par 30 fabriquerait un échec qui n'existe pas.
      final l = _line(candidates: 30, withResult: 8, admitted: 6);
      expect(l.successRate, closeTo(75, 0.001));
    });

    test('un échec total reste 0 %, et se distingue d\'une attente', () {
      final connu = _line(candidates: 5, withResult: 5);
      expect(connu.successRate, 0);
      expect(_line(candidates: 5).successRate, isNull);
    });
  });

  group('Ligne école du cockpit', () {
    test('des candidats sans aucune transmission = école à risque', () {
      expect(_school(candidates: 12).hasCandidatesNotTransmitted, isTrue);
    });

    test('une école sans candidat n\'est jamais à risque', () {
      // Sans elle, toute école du réseau non concernée par la session
      // apparaîtrait en alerte rouge.
      expect(_school().hasCandidatesNotTransmitted, isFalse);
    });

    test('transmettre lève l\'alerte', () {
      expect(
          _school(candidates: 12, transmissions: 1).hasCandidatesNotTransmitted,
          isFalse);
    });

    test('les restes à faire se déduisent, ils ne se saisissent pas', () {
      final s = _school(candidates: 30, complete: 22, withResult: 8);
      expect(s.incomplete, 8, reason: 'dossiers encore incomplets');
      expect(s.pending, 22, reason: 'candidats sans résultat proclamé');
    });

    test('un réseau à jour n\'affiche aucun reste', () {
      final s = _school(candidates: 10, complete: 10, withResult: 10);
      expect(s.incomplete, 0);
      expect(s.pending, 0);
    });
  });
}
