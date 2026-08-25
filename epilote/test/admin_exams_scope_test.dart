import 'package:epilote/features/admin_groupe/providers/admin_exams_provider.dart';
import 'package:epilote/features/admin_groupe/providers/ministry_exam_rows.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN CHIFFRE PAR EXAMEN — la correction de justesse du cockpit.
//
//  La DEC proclame BET 77,59 %, BEP 74,29 %, BAC T/P 51,61 %. Elle ne publie
//  JAMAIS un taux tous examens confondus, et pour cause : additionner un
//  brevet et un baccalauréat ne décrit aucune réalité. Le cockpit le faisait
//  sur ses huit indicateurs et ses deux ventilations.
//
//  Deuxième règle, moins visible : une attestation de stage ne conditionne que
//  les bacs technique et professionnel. Afficher « Bacs bloqués » pendant
//  qu'on regarde le BET, c'est promener une alerte hors de son périmètre — et
//  une alerte qu'on apprend à ignorer ne protège plus de rien.
// ════════════════════════════════════════════════════════════════════════════
MinistryCandidateRow _row({
  String schoolId = 's1',
  String schoolName = 'CET de Kinkala',
  String? department = 'Pool',
  String examCode = 'BET',
  String examShortName = 'BET',
  String? filiere = 'Mécanique',
  String dossier = 'valide',
  String result = 'admis',
  bool hasAttestation = true,
}) =>
    MinistryCandidateRow(
      schoolId: schoolId,
      schoolName: schoolName,
      department: department,
      examCode: examCode,
      examShortName: examShortName,
      tutelle: 'metp',
      sessionId: 'sess-$examCode',
      filiereLabel: filiere,
      dossierStatus: dossier,
      result: result,
      hasAttestation: hasAttestation,
    );

void main() {
  final rows = [
    _row(), // BET admis
    _row(result: 'ajourne'), // BET ajourné
    _row(result: 'en_attente'), // BET non proclamé
    _row(
        examCode: 'BAC_T',
        examShortName: 'BAC T',
        filiere: 'Électrotechnique',
        hasAttestation: false), // BAC T admis, sans stage
    _row(
        examCode: 'BAC_T',
        examShortName: 'BAC T',
        filiere: 'Électrotechnique',
        result: 'ajourne'),
  ];

  MinistryExamsData build({String? examCode}) => buildMinistryExamsData(
        rows: rows,
        transmissions: const [],
        internshipsTotal: 10,
        attestationsTotal: 4,
        yearLabel: '2025-2026',
        examCode: examCode,
      );

  test('sans filtre, le cockpit voit tout le réseau', () {
    final d = build();
    expect(d.totalCandidates, 5);
    expect(d.totalAdmitted, 2);
    expect(d.totalWithResult, 4); // « en_attente » n'est pas un résultat
  });

  test('filtrer sur un examen ne garde que ses candidats', () {
    final d = build(examCode: 'BET');
    expect(d.totalCandidates, 3);
    expect(d.totalAdmitted, 1);
    expect(d.totalWithResult, 2);
    expect(d.successRate, closeTo(50, 0.001));
  });

  test('forExam recompose sans requête et reste réversible', () {
    expect(build().forExam('BAC_T').totalCandidates, 2);
    expect(build(examCode: 'BET').forExam(null).totalCandidates, 5);
    expect(build(examCode: 'BET').forExam('BAC_T').totalAdmitted, 1);
  });

  test('la ventilation par filière suit le périmètre choisi', () {
    expect(build(examCode: 'BET').byFiliere.map((l) => l.label), ['Mécanique']);
    expect(build(examCode: 'BAC_T').byFiliere.map((l) => l.label),
        ['Électrotechnique']);
    expect(build().byFiliere.length, 2);
  });

  test('la ventilation par département suit le périmètre choisi', () {
    expect(build(examCode: 'BET').byDepartment.single.total, 3);
    expect(build().byDepartment.single.total, 5);
  });

  test('les KPI stages ne concernent que les bacs technique et pro', () {
    expect(build().showsInternshipKpis, isTrue); // « Tous »
    expect(build(examCode: 'BAC_T').showsInternshipKpis, isTrue);
    expect(build(examCode: 'BET').showsInternshipKpis, isFalse);
  });

  test('bacs bloqués = bac pro sans attestation, jamais un BET', () {
    expect(build().bacBlocked, 1);
    expect(build(examCode: 'BAC_T').bacBlocked, 1);
    expect(build(examCode: 'BET').bacBlocked, 0);
  });

  test('les puces d\'examen restent stables quel que soit le filtre', () {
    // Sélectionner le BET ne doit pas faire disparaître le BAC T de la barre :
    // on ne pourrait plus en sortir.
    final codes = build(examCode: 'BET').examOptions.map((e) => e.code);
    expect(codes, containsAll(<String>['BET', 'BAC_T']));
    expect(build(examCode: 'BET').examOptions.first.candidates, 3); // tri par effectif
    expect(build().examOptions.length, 2);
  });

  test('la session compte dans le périmètre, pas dans le réseau entier', () {
    expect(build().sessionCount, 2);
    expect(build(examCode: 'BET').sessionCount, 1);
  });

  test('un taux sans résultat connu reste null, jamais zéro', () {
    final none = buildMinistryExamsData(
      rows: [_row(result: 'en_attente')],
      transmissions: const [],
      internshipsTotal: 0,
      attestationsTotal: 0,
      yearLabel: null,
    );
    expect(none.successRate, isNull);
    expect(none.byFiliere.single.rate, isNull);
    expect(none.byDepartment.single.rate, isNull);
  });

  test('une école sans transmission est à risque, et repérable par son id', () {
    final d = buildMinistryExamsData(
      rows: [_row(schoolId: 'a'), _row(schoolId: 'b')],
      transmissions: const [
        MinistryTransmissionRow(
            schoolId: 'a', status: 'accuse_reception', transmittedAt: null),
      ],
      internshipsTotal: 0,
      attestationsTotal: 0,
      yearLabel: null,
    );
    expect(d.schoolsAtRisk, 1);
    expect(d.transmittedSchoolIds, {'a'});
    expect(d.transmissionsAcknowledged, 1);
  });

  test('l\'entonnoir décroît : déclarés ≥ déposés ≥ admis', () {
    final bars = funnelByExam(rows);
    final bet = bars.firstWhere((b) => b.label == 'BET');
    expect(bet.declared, 3);
    expect(bet.submitted, 3); // dossier « valide » = déposé
    expect(bet.admitted, 1);
    for (final b in bars) {
      expect(b.declared, greaterThanOrEqualTo(b.submitted));
      expect(b.submitted, greaterThanOrEqualTo(b.admitted));
    }
  });

  test('sur un examen, l\'entonnoir se lit par département', () {
    final bars =
        funnelByDepartment(rows.where((r) => r.examCode == 'BET').toList());
    expect(bars.single.label, 'Pool');
    expect(bars.single.declared, 3);
  });

  test('un département non renseigné porte un libellé, pas un vide', () {
    final bars = funnelByDepartment([_row(department: null)]);
    expect(bars.single.label, 'Non renseigné');
  });
}
