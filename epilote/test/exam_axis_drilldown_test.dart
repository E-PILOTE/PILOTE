import 'package:epilote/features/admin_groupe/providers/ministry_exam_rows.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « MÉCANIQUE 42 % » — ET ENSUITE ?
//
//  La question qui suit une ventilation est toujours la même : dans quelles
//  écoles. Une card qui n'y répond pas est un constat, pas du pilotage — on
//  repartait vers un autre écran, ou on téléphonait.
//
//  Deux pièges que ces tests verrouillent. Une école dont AUCUN résultat n'est
//  proclamé ne vaut pas 0 % : elle n'a pas de taux. Et le classement doit la
//  ranger à part, sinon elle occupe le bas du tableau comme si elle était
//  sinistrée — et le ministère relance un établissement irréprochable.
// ════════════════════════════════════════════════════════════════════════════
MinistryCandidateRow _row({
  required String schoolId,
  required String schoolName,
  String? filiere = 'Mécanique',
  String? department = 'Pool',
  String result = 'admis',
}) =>
    MinistryCandidateRow(
      schoolId: schoolId,
      schoolName: schoolName,
      department: department,
      examCode: 'BET',
      examShortName: 'BET',
      tutelle: 'metp',
      sessionId: 'sess-1',
      filiereLabel: filiere,
      dossierStatus: 'valide',
      result: result,
      hasAttestation: true,
    );

void main() {
  final rows = [
    _row(schoolId: 'a', schoolName: 'LT Poaty'),
    _row(schoolId: 'a', schoolName: 'LT Poaty', result: 'ajourne'),
    _row(schoolId: 'b', schoolName: 'CET Owando', result: 'ajourne'),
    _row(schoolId: 'b', schoolName: 'CET Owando', result: 'ajourne'),
    _row(schoolId: 'c', schoolName: 'CET Sibiti', result: 'en_attente'),
    _row(schoolId: 'd', schoolName: 'LT Dolisie', filiere: 'Électrotechnique'),
  ];

  List<AxisSchoolLine> mecanique({Set<String> transmitted = const {'a'}}) =>
      schoolsForAxis(rows,
          axis: ExamAxis.filiere,
          label: 'Mécanique',
          transmittedSchoolIds: transmitted);

  test('l\'axe ne retient que ses propres candidats', () {
    expect(mecanique().map((s) => s.schoolId), isNot(contains('d')));
    expect(mecanique().length, 3);
  });

  test('le meilleur taux vient en tête', () {
    final s = mecanique();
    expect(s.first.schoolName, 'LT Poaty');
    expect(s.first.rate, closeTo(0.5, 0.001));
  });

  test('une école sans résultat proclamé n\'a pas de taux, et non zéro', () {
    final sibiti = mecanique().firstWhere((s) => s.schoolId == 'c');
    expect(sibiti.rate, isNull);
    expect(sibiti.known, 0);
    expect(sibiti.candidates, 1);
  });

  test('les taux inconnus se rangent après les taux connus', () {
    expect(mecanique().last.schoolId, 'c');
  });

  test('un 0 % PROCLAMÉ est un vrai zéro, et se classe comme tel', () {
    final owando = mecanique().firstWhere((s) => s.schoolId == 'b');
    expect(owando.admitted, 0);
    expect(owando.known, 2);
    expect(owando.rate, 0);
    // Owando (0 % connu) passe AVANT Sibiti (rien de proclamé).
    final ids = mecanique().map((s) => s.schoolId).toList();
    expect(ids.indexOf('b'), lessThan(ids.indexOf('c')));
  });

  test('une école qui n\'a rien transmis est signalée', () {
    expect(mecanique().firstWhere((s) => s.schoolId == 'a').transmitted, isTrue);
    expect(mecanique().firstWhere((s) => s.schoolId == 'b').transmitted, isFalse);
  });

  test('l\'axe département se lit avec les mêmes règles', () {
    final byDept = schoolsForAxis(rows,
        axis: ExamAxis.departement,
        label: 'Pool',
        transmittedSchoolIds: const {});
    expect(byDept.length, 4); // les 4 écoles, filières confondues
    expect(byDept.first.rate, isNotNull);
  });

  test('une filière vide se range sous « Non renseigné », des deux côtés', () {
    final orphan = [_row(schoolId: 'x', schoolName: 'CET X', filiere: null)];
    final lines = schoolsForAxis(orphan,
        axis: ExamAxis.filiere,
        label: 'Non renseigné',
        transmittedSchoolIds: const {});
    // Sans cette convention partagée avec groupExamLines, cliquer la ligne
    // « Non renseigné » de la card ouvrirait une modal vide.
    expect(lines.single.schoolId, 'x');
  });
}
