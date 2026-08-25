import 'package:epilote/features/admin_groupe/providers/school_exam_candidates_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUI BLOQUE LE DOSSIER ?
//
//  La fiche d'établissement disait « 8 complets sur 12 ». Ça ne se traite pas :
//  le ministère relançait à l'aveugle, et le chef d'établissement recevait un
//  reproche sans objet. « Vos 6 candidats de F5 sans acte de naissance », si.
//
//  Un établissement congolais couvre souvent collège ET lycée, parfois du
//  professionnel. Le groupement cycle → examen → filière est la seule façon de
//  lire cette liste sans la trier à la main.
// ════════════════════════════════════════════════════════════════════════════
SchoolCandidate _c({
  required String id,
  required String name,
  String cycle = 'college',
  String exam = 'BET',
  String? filiere,
  String dossier = 'valide',
  List<String> missing = const [],
}) =>
    SchoolCandidate(
      id: id,
      fullName: name,
      className: '3ème A',
      cycleCode: cycle,
      levelCode: '3eme',
      examShortName: exam,
      examCode: exam,
      filiereLabel: filiere,
      candidateNumber: 'C-$id',
      dossierStatus: dossier,
      missingDocuments: missing,
      isRepeater: false,
    );

void main() {
  final rows = [
    _c(id: '1', name: 'MBEMBA Alice'),
    _c(
        id: '2',
        name: 'OKEMBA Jean',
        dossier: 'incomplet',
        missing: const ['Acte de naissance']),
    _c(
        id: '3',
        name: 'NGOMA Paul',
        cycle: 'lycee',
        exam: 'BAC T',
        filiere: 'F5',
        dossier: 'incomplet',
        missing: const ['Attestation de stage']),
    _c(id: '4', name: 'LOEMBA Sarah', cycle: 'lycee', exam: 'BAC T', filiere: 'F3'),
  ];

  test('le groupement suit cycle → examen → filière', () {
    final g = groupSchoolCandidates(rows);
    expect(g.length, 3);
    expect(g.first.cycleLabel, 'Collège');
    expect(g.first.candidates.length, 2);
    expect(g.map((x) => x.filiereLabel), containsAll(<String?>[null, 'F5', 'F3']));
  });

  test('le collège vient avant le lycée', () {
    // L'ordre pédagogique, pas l'ordre alphabétique ni celui de la base : on
    // lit un établissement du plus jeune au plus âgé.
    expect(groupSchoolCandidates(rows).map((g) => g.cycleLabel).toList(),
        ['Collège', 'Lycée', 'Lycée']);
  });

  test('le filtre cycle ne garde que son cycle', () {
    final g = groupSchoolCandidates(rows, cycle: 'lycee');
    expect(g.every((x) => x.cycleLabel == 'Lycée'), isTrue);
    expect(g.expand((x) => x.candidates).length, 2);
  });

  test('le filtre filière ne garde que sa filière', () {
    final g = groupSchoolCandidates(rows, filiere: 'F5');
    expect(g.single.candidates.single.fullName, 'NGOMA Paul');
  });

  test('« incomplets seulement » isole ceux qui bloquent', () {
    final g = groupSchoolCandidates(rows, incompleteOnly: true);
    final names = g.expand((x) => x.candidates).map((c) => c.fullName);
    expect(names, containsAll(<String>['OKEMBA Jean', 'NGOMA Paul']));
    expect(names, isNot(contains('MBEMBA Alice')));
  });

  test('un groupe vidé par les filtres disparaît au lieu de rester vide', () {
    final g = groupSchoolCandidates(rows, cycle: 'college', incompleteOnly: true);
    expect(g.length, 1);
    expect(g.single.candidates.single.fullName, 'OKEMBA Jean');
  });

  test('les pièces manquantes sont nommées, pas comptées', () {
    final paul = rows.firstWhere((c) => c.id == '3');
    expect(paul.isComplete, isFalse);
    expect(paul.missingDocuments, ['Attestation de stage']);
  });

  test('un dossier incomplet SANS liste de pièces reste signalé', () {
    // La colonne `missing_documents` peut être vide alors que le dossier est
    // marqué incomplet. Le badge doit alerter quand même, sinon l'écran
    // affirmerait que tout va bien.
    final vague = _c(id: '9', name: 'X Y', dossier: 'incomplet');
    expect(vague.isComplete, isFalse);
    expect(vague.missingDocuments, isEmpty);
  });

  test('les filières se listent pour alimenter le filtre', () {
    expect(filiereOptions(rows), ['F3', 'F5']);
    expect(cycleOptions(rows), ['college', 'lycee']);
  });
}
