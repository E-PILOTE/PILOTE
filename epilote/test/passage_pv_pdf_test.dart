import 'package:epilote/features/evaluation/providers/passage_provider.dart';
import 'package:epilote/features/evaluation/services/passage_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PROCÈS-VERBAL DE PASSAGE DOIT SORTIR — surtout pour une grande classe.
//
//  Le PV est la pièce signée : sans lui, la délibération n'existe pas
//  administrativement. Or le paquet `pdf` ne tronque pas un document trop
//  long, il le REFUSE (`TooManyPagesException`) — l'export des inscriptions
//  était cassé exactement comme ça, invisible tant qu'on testait sur des
//  classes de quinze. Une classe congolaise en compte quarante à soixante.
//
//  Ces tests montent donc le PV sur des effectifs réels et vérifient qu'il
//  rend, qu'il passe à la page, et qu'il survit aux cas dégradés (aucune note,
//  trimestres non déclarés).
// ════════════════════════════════════════════════════════════════════════════

PassageEntry _entry(int i, {List<double?>? trims}) {
  final t = trims ?? [8.0 + (i % 9), 9.0 + (i % 8), 10.0 + (i % 7)];
  final avg = annualAverageOf(t);
  return PassageEntry(
    enrollmentId: 'enr-$i',
    studentId: 'stu-$i',
    studentName: 'NGOMA Élève numéro $i',
    matricule: 'MAT-2026-${i.toString().padLeft(4, '0')}',
    trimesterAverages: t,
    annualAverage: avg,
    rank: i + 1,
    totalStudents: 60,
    decision: avg == null ? null : (avg >= 10 ? 'passe' : 'redouble'),
    decidedAverage: avg,
    targetClassId: 'cls-next',
    reenrolled: false,
    alreadyRepeating: i % 11 == 0,
  );
}

PassageSession _session(int n, {int trimesters = 3, List<double?>? trims}) =>
    PassageSession(
      entries: [for (var i = 0; i < n; i++) _entry(i, trims: trims)],
      trimesters: [
        for (var k = 1; k <= trimesters; k++)
          PassageTrimester(
              id: 't$k', label: '${k}e trimestre', number: k, hasGrades: true),
      ],
      classAverage: 11.2,
      evaluationCount: 42,
      nextYearId: 'y-next',
      nextYearLabel: '2026-2027',
      upperClass: const TargetClass(id: 'cls-next', name: '5ème A'),
      repeatClass: const TargetClass(id: 'cls-same', name: '6ème A'),
    );

/// Monte le PV et rend sa taille. `build` LÈVE si le document ne tient pas :
/// c'est l'échec qu'on traque, la taille ne sert qu'à voir qu'il grossit avec
/// l'effectif — un document qui ne grossit pas est un document tronqué.
Future<int> _size(PassageSession s) async {
  final bytes = await PassagePdfService.build(
    session: s,
    className: '6ème A',
    yearLabel: '2025-2026',
    schoolName: 'Collège d\'Enseignement Technique de Kinkala',
  );
  expect(bytes.length, greaterThan(1000));
  return bytes.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  test('une classe de 60 élèves produit bien un PV, et un PV plus gros',
      () async {
    final petite = await _size(_session(15));
    final pleine = await _size(_session(60));
    expect(pleine, greaterThan(petite),
        reason: 'Soixante élèves doivent peser plus que quinze : sinon des '
            'lignes ont disparu en route.');
  });

  test('un PV sans aucune note ne fait pas échouer le document', () async {
    // Année délibérée trop tôt, ou classe dont les notes n'ont pas été saisies.
    final s = _session(30, trims: const [null, null, null]);
    expect(s.entries.first.annualAverage, isNull);
    await _size(s);
  });

  test('une année sans trimestres déclarés s\'imprime quand même', () async {
    await _size(_session(40, trimesters: 0));
  });

  test('une classe vide reste imprimable', () async {
    await _size(_session(0));
  });
}
