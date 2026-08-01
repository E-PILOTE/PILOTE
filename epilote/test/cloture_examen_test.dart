import 'package:epilote/features/evaluation/providers/cloture_examen_provider.dart';
import 'package:epilote/features/evaluation/providers/passage_provider.dart'
    show TargetClass;
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CLÔTURE DES CLASSES D'EXAMEN
//
//  Ce que ces tests protègent, c'est la traduction d'une proclamation en
//  scolarité. Une erreur ici ne fait pas planter l'application : elle fait
//  redoubler un admis, ou perdre un ajourné à la rentrée.
// ════════════════════════════════════════════════════════════════════════════

ExamClosureEntry _entry({
  String id = 'e1',
  String? result,
  String? candidateNumber,
  String? decision,
  String? targetClassId,
  bool reenrolled = false,
  String status = 'active',
  double? average,
}) =>
    ExamClosureEntry(
      enrollmentId: id,
      studentId: 's-$id',
      studentName: 'Élève $id',
      matricule: 'MAT-$id',
      candidateNumber: candidateNumber,
      result: result,
      examAverage: average,
      mention: null,
      decision: decision,
      targetClassId: targetClassId,
      reenrolled: reenrolled,
      enrollmentStatus: status,
    );

ExamClosureSession _session(
  List<ExamClosureEntry> entries, {
  TargetClass? nextLevel,
  TargetClass? repeat = const TargetClass(id: 'c-same', name: '3ème A'),
  String? nextYearId = 'y2',
  bool nextYearHasStructure = true,
}) =>
    ExamClosureSession(
      entries: entries,
      examLabel: 'BEPC — session 2026',
      nextYearId: nextYearId,
      nextYearLabel: '2026-2027',
      nextLevelClass: nextLevel,
      repeatClass: repeat,
      nextYearHasStructure: nextYearHasStructure,
      qualifyPending: false,
    );

void main() {
  group('Le verdict se lit sur la proclamation', () {
    test('admis passe, ajourné et absent redoublent', () {
      expect(verdictFromExamResult('admis'), 'passe');
      expect(verdictFromExamResult('ajourne'), 'redouble');
      expect(verdictFromExamResult('absent'), 'redouble');
    });

    test('l\'absent redouble : ne pas se présenter ne donne pas le diplôme',
        () {
      // Le piège serait de traiter « absent » comme « pas de résultat » et de
      // le laisser sans suite : l'élève disparaîtrait de la rentrée.
      expect(verdictFromExamResult('absent'), isNotNull);
    });

    test('la fraude ne propose rien — c\'est une affaire disciplinaire', () {
      expect(verdictFromExamResult('fraude'), isNull);
    });

    test('en attente et non présenté ne proposent rien', () {
      expect(verdictFromExamResult('en_attente'), isNull);
      expect(verdictFromExamResult(null), isNull);
    });
  });

  group('Ce que le report écrirait', () {
    test('ne compte que les proclamés sans décision', () {
      final s = _session([
        _entry(id: 'a', result: 'admis'),
        _entry(id: 'b', result: 'ajourne'),
        _entry(id: 'c', result: 'en_attente'),
        _entry(id: 'd'), // non présenté
        _entry(id: 'e', result: 'fraude'),
        _entry(id: 'f', result: 'admis', decision: 'passe'), // déjà décidé
      ]);
      expect(s.reportableCount, 2);
    });

    test('une décision prise à la main n\'est jamais recouverte', () {
      // Le chef d'établissement a fait passer un ajourné par dérogation : le
      // report ne doit pas le renvoyer redoubler.
      final s = _session([_entry(result: 'ajourne', decision: 'passe')]);
      expect(s.reportableCount, 0);
    });
  });

  group('Les compteurs de classe', () {
    final s = _session([
      _entry(id: 'a', result: 'admis', candidateNumber: 'C1'),
      _entry(id: 'b', result: 'admis', candidateNumber: 'C2'),
      _entry(id: 'c', result: 'ajourne', candidateNumber: 'C3'),
      _entry(id: 'd', result: 'absent', candidateNumber: 'C4'),
      _entry(id: 'e', result: 'en_attente', candidateNumber: 'C5'),
      _entry(id: 'f'), // jamais présenté
    ]);

    test('admis, ajournés, absents, en attente', () {
      expect(s.admittedCount, 2);
      expect(s.failedCount, 1);
      expect(s.absentCount, 1);
      expect(s.pendingCount, 1);
    });

    test('les élèves non présentés sont comptés, pas effacés', () {
      // Les faire disparaître de l'écran, c'est les faire disparaître de
      // l'école : personne ne déciderait jamais de leur sort.
      expect(s.notPresentedCount, 1);
      expect(s.presentedCount, 5);
    });
  });

  group('Les sortants diplômés', () {
    test('sans niveau suivant dans l\'établissement, l\'admis sort', () {
      final s = _session(
        [_entry(id: 'a', result: 'admis'), _entry(id: 'b', result: 'ajourne')],
        nextLevel: null,
      );
      expect(s.leavers.map((e) => e.enrollmentId), ['a']);
    });

    test('avec un niveau suivant ouvert, personne ne sort', () {
      final s = _session(
        [_entry(id: 'a', result: 'admis')],
        nextLevel: const TargetClass(id: 'c-2nde', name: '2nde A'),
      );
      expect(s.leavers, isEmpty);
    });

    test('une structure non reconduite ne fait sortir personne', () {
      // Le piège : `nextLevelClass` est null aussi bien parce que l'école
      // n'accueille pas la suite QUE parce que personne n'a encore créé les
      // classes de l'an prochain. Confondre les deux ferait prononcer la
      // sortie — irréversible — d'une classe entière que le lycée attend.
      final s = _session(
        [_entry(id: 'a', result: 'admis')],
        nextLevel: null,
        repeat: null,
        nextYearHasStructure: false,
      );
      expect(s.leavers, isEmpty);
      expect(s.admittedLeave, isFalse);
    });

    test('structure montée mais aucun niveau suivant : là, ils sortent', () {
      final s = _session(
        [_entry(id: 'a', result: 'admis')],
        nextLevel: null,
        nextYearHasStructure: true,
      );
      expect(s.admittedLeave, isTrue);
      expect(s.leavers, hasLength(1));
    });

    test('une sortie déjà prononcée ne se prononce pas deux fois', () {
      final s = _session(
        [_entry(id: 'a', result: 'admis', status: 'graduated')],
        nextLevel: null,
      );
      expect(s.leavers, isEmpty);
      expect(s.entries.first.graduated, isTrue);
    });
  });

  group('La réinscription a besoin d\'un endroit où réinscrire', () {
    test('sans année suivante, rien n\'est possible', () {
      final s = _session([_entry(result: 'ajourne')], nextYearId: null);
      expect(s.canReenroll, isFalse);
    });

    test('sans aucune classe d\'accueil, rien n\'est possible', () {
      final s = _session([_entry(result: 'ajourne')], repeat: null);
      expect(s.canReenroll, isFalse);
    });

    test('la classe de redoublement suffit — l\'admis peut sortir', () {
      // Cas d\'un collège : les ajournés refont la 3ème, les admis s\'en vont.
      final s = _session([_entry(result: 'ajourne')]);
      expect(s.canReenroll, isTrue);
    });
  });

  group('L\'état d\'un élève', () {
    test('proclamé exclut « en attente » et l\'absence de candidature', () {
      expect(_entry(result: 'admis').proclaimed, isTrue);
      expect(_entry(result: 'en_attente').proclaimed, isFalse);
      expect(_entry().proclaimed, isFalse);
    });

    test('un numéro de candidat suffit à dire que l\'élève a été présenté', () {
      // La DEC attribue le numéro à l'inscription, le résultat vient des mois
      // plus tard : entre les deux, l'élève est bien un candidat.
      expect(_entry(candidateNumber: 'C1').presented, isTrue);
    });
  });

  group('Les couleurs et libellés de résultat', () {
    test('chaque résultat a un libellé lisible', () {
      expect(examResultTone('admis').label, 'Admis');
      expect(examResultTone('ajourne').label, 'Ajourné');
      expect(examResultTone('absent').label, 'Absent');
      expect(examResultTone('fraude').label, 'Fraude');
      expect(examResultTone(null).label, 'Non présenté');
    });
  });
}
