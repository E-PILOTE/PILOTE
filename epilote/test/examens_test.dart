import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/providers/examens_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EXAMENS — logique pure côté client.
//
//  Ce qui n'est PAS testé ici, volontairement : la résolution « quelle classe
//  prépare quel examen ». Elle vit UNIQUEMENT en SQL (resolve_class_exam,
//  migration 0044) et est vérifiée en base. La rejouer en Dart pour la tester
//  reviendrait à la dupliquer — précisément ce que la conception évite.
// ════════════════════════════════════════════════════════════════════════════

ExamClassRow _row({
  String name = '3e A',
  ClassExamStatus status = ClassExamStatus.examen,
  String? examCode = 'BET',
  int effectif = 30,
  int candidates = 0,
  bool overridden = false,
}) =>
    ExamClassRow(
      id: 'c-$name',
      name: name,
      levelCode: '3e',
      cycleCode: 'college',
      filiereLabel: null,
      status: status,
      examCode: examCode,
      examShortName: examCode,
      examName: 'Brevet d\'Études Techniques',
      isOverridden: overridden,
      effectif: effectif,
      candidates: candidates,
    );

ExamSessionRow _session({DateTime? closesAt, String status = 'open'}) =>
    ExamSessionRow(
      id: 's1',
      examCode: 'BET',
      examShortName: 'BET',
      yearLabel: '2025-2026',
      opensAt: DateTime(2025, 12, 8),
      closesAt: closesAt,
      writtenFrom: DateTime(2026, 6, 23),
      maxAge: 20,
      status: status,
    );

void main() {
  group('ClassExamStatus.parse', () {
    test('mappe les valeurs de la base', () {
      expect(ClassExamStatus.parse('examen'), ClassExamStatus.examen);
      expect(ClassExamStatus.parse('a_qualifier'), ClassExamStatus.aQualifier);
      expect(ClassExamStatus.parse('passage'), ClassExamStatus.passage);
    });

    test('retombe sur passage pour une valeur inconnue ou nulle', () {
      // Un statut inattendu ne doit JAMAIS faire croire à une classe d'examen :
      // le repli sûr est « passage » (aucune alerte fausse).
      expect(ClassExamStatus.parse(null), ClassExamStatus.passage);
      expect(ClassExamStatus.parse('n_importe_quoi'), ClassExamStatus.passage);
    });
  });

  group('ExamClassRow.missing', () {
    test('compte les élèves non encore inscrits', () {
      expect(_row(effectif: 30, candidates: 12).missing, 18);
    });

    test('vaut 0 quand tout le monde est inscrit', () {
      expect(_row(effectif: 30, candidates: 30).missing, 0);
    });

    test('ne devient jamais négatif (plus de candidats que d\'inscrits)', () {
      // Cas réel : un candidat libre ou un redoublant rattaché à la classe.
      expect(_row(effectif: 30, candidates: 33).missing, 0);
    });
  });

  group('ExamOverview', () {
    test('sépare classes d\'examen et anomalies, ignore le passage', () {
      final o = ExamOverview(classes: [
        _row(name: '3e A'),
        _row(name: '3e B'),
        _row(name: 'Tle E', status: ClassExamStatus.aQualifier, examCode: null),
        _row(name: '6e A', status: ClassExamStatus.passage, examCode: null),
      ], sessions: const []);

      expect(o.examClasses.length, 2);
      expect(o.anomalies.length, 1);
      expect(o.anomalies.single.name, 'Tle E');
    });

    test('les totaux ne comptent QUE les classes d\'examen', () {
      // Une classe de passage ne doit jamais gonfler « élèves concernés ».
      final o = ExamOverview(classes: [
        _row(name: '3e A', effectif: 30, candidates: 10),
        _row(name: '3e B', effectif: 25, candidates: 25),
        _row(name: '6e A', status: ClassExamStatus.passage, effectif: 40),
      ], sessions: const []);

      expect(o.studentsTotal, 55);
      expect(o.candidatesTotal, 35);
      expect(o.missingTotal, 20);
    });

    test('ne retient que les sessions des examens réellement préparés', () {
      const bepc = ExamSessionRow(
        id: 's2',
        examCode: 'BEPC',
        examShortName: 'BEPC',
        yearLabel: '2025-2026',
        opensAt: null,
        closesAt: null,
        writtenFrom: null,
        maxAge: null,
        status: 'open',
      );
      final o = ExamOverview(
        classes: [_row(examCode: 'BET')],
        sessions: [_session(), bepc],
      );

      // L'école ne prépare que le BET : la session BEPC ne la concerne pas.
      expect(o.relevantSessions.map((s) => s.examCode), ['BET']);
    });

    test('aucune classe d\'examen -> tout est à zéro, sans exception', () {
      const o = ExamOverview(classes: [], sessions: []);
      expect(o.examClasses, isEmpty);
      expect(o.studentsTotal, 0);
      expect(o.missingTotal, 0);
      expect(o.relevantSessions, isEmpty);
    });
  });

  group('ExamSessionRow.daysLeft', () {
    test('compte les jours avant clôture des inscriptions', () {
      final in10 = DateTime.now().add(const Duration(days: 10));
      final d = _session(closesAt: DateTime(in10.year, in10.month, in10.day))
          .daysLeft;
      expect(d, 10);
    });

    test('devient négatif une fois la clôture passée', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final d = _session(closesAt: DateTime(past.year, past.month, past.day))
          .daysLeft;
      expect(d, lessThan(0));
    });

    test('vaut null sans date de clôture (jamais 0, qui voudrait dire « aujourd\'hui »)',
        () {
      expect(_session(closesAt: null).daysLeft, isNull);
    });

    test('isOpen suit le statut de la session', () {
      expect(_session().isOpen, isTrue);
      expect(_session(status: 'closed').isOpen, isFalse);
    });
  });
}
