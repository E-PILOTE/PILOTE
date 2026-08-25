import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/providers/student_history_provider.dart';
import 'package:epilote/features/examens/widgets/student_history_dialog.dart'
    show kPrerequisites;

// ════════════════════════════════════════════════════════════════════════════
//  Le PARCOURS d'un élève — plusieurs examens, plusieurs années.
//
//  Ce que ces tests protègent : l'éligibilité déduite de NOTRE base. Pour
//  s'inscrire au bac il faut le BET (ou BEPC/BEMG/BEP). Si l'élève l'a passé
//  chez nous, nous le savons — inutile d'attendre le rejet de la DEC.
//  Mais « nous ne le savons pas » ne veut PAS dire « il ne l'a pas » : il a pu
//  l'obtenir ailleurs. Un prérequis absent AVERTIT, il n'interdit jamais.
// ════════════════════════════════════════════════════════════════════════════

ExamHistoryEntry _exam(
  String code, {
  String result = 'admis',
  String year = '2023-2024',
}) =>
    ExamHistoryEntry(
      candidateId: 'c-$code-$year',
      examCode: code,
      examShortName: code,
      yearLabel: year,
      className: null,
      result: result,
      average: null,
      mention: null,
      candidateNumber: null,
      decidedAt: null,
      resultSource: 'saisie_manuelle',
      isRepeater: false,
    );

InternshipHistoryEntry _stage({DateTime? attestation}) =>
    InternshipHistoryEntry(
      internshipId: 'i1',
      title: 'Stage atelier',
      companyName: 'SOTEC',
      startDate: DateTime(2025, 3, 1),
      endDate: DateTime(2025, 4, 30),
      status: 'termine',
      grade: 14,
      attestationIssuedAt: attestation,
      yearLabel: '2024-2025',
    );

StudentHistory _history({
  List<ExamHistoryEntry> exams = const [],
  List<InternshipHistoryEntry> stages = const [],
}) =>
    StudentHistory(exams: exams, internships: stages);

void main() {
  group('StudentHistory — les diplômes obtenus', () {
    test('seul un examen ADMIS compte comme diplôme', () {
      final h = _history(exams: [
        _exam('BET', result: 'admis'),
        _exam('BEPC', result: 'ajourne'),
        _exam('CAP', result: 'absent'),
        _exam('BEP', result: 'fraude'),
        _exam('BTF', result: 'en_attente'),
      ]);
      expect(h.diplomas.map((e) => e.examCode), ['BET']);
    });

    test('un résultat en attente n\'est ni un échec ni un diplôme', () {
      final e = _exam('BAC_T', result: 'en_attente');
      expect(e.isPending, isTrue);
      expect(e.isAdmitted, isFalse);
      expect(_history(exams: [e]).diplomas, isEmpty);
    });

    test('un résultat nul est traité comme en attente', () {
      expect(_exam('BET', result: 'null').isPending, isFalse);
      final e = const ExamHistoryEntry(
        candidateId: 'x', examCode: 'BET', examShortName: 'BET',
        yearLabel: null, className: null, result: null, average: null,
        mention: null, candidateNumber: null, decidedAt: null,
        resultSource: null, isRepeater: false,
      );
      expect(e.isPending, isTrue);
    });
  });

  group('Éligibilité — ce que nous savons déjà', () {
    test('BAC_T : le BET obtenu satisfait le prérequis', () {
      final h = _history(exams: [_exam('BET')]);
      final found = h.diplomaAmong(kPrerequisites['BAC_T']!);
      expect(found, isNotNull);
      expect(found!.examCode, 'BET');
      expect(found.yearLabel, '2023-2024');
    });

    test('BAC_T : un BET AJOURNÉ ne satisfait rien', () {
      final h = _history(exams: [_exam('BET', result: 'ajourne')]);
      expect(h.diplomaAmong(kPrerequisites['BAC_T']!), isNull);
    });

    test('BAC_T accepte BEPC, BET ou BEP — indifféremment', () {
      for (final code in ['BEPC', 'BET', 'BEP']) {
        final h = _history(exams: [_exam(code)]);
        expect(h.diplomaAmong(kPrerequisites['BAC_T']!)?.examCode, code,
            reason: code);
      }
    });

    test('BAC (code fusionné, mig. 0105) garde les prérequis du BAC_T', () {
      // Le référentiel METP ne porte plus qu'un baccalauréat. Si la clé `BAC`
      // manquait, l'écran n'annoncerait AUCUN prérequis à un candidat au bac —
      // la pire des régressions silencieuses ici.
      expect(kPrerequisites['BAC'], kPrerequisites['BAC_T']);
      final h = _history(exams: [_exam('BET')]);
      expect(h.diplomaAmong(kPrerequisites['BAC']!)?.examCode, 'BET');
    });

    test('le BET n\'exige AUCUN prérequis (il suit la 3e technique)', () {
      // Absent de la table = rien à vérifier. C'est la note officielle METP :
      // le BET est le seul examen sans diplôme antérieur au dossier.
      expect(kPrerequisites.containsKey('BET'), isFalse);
    });

    test('BEP, CAP et BTF exigent BEPC ou BET', () {
      for (final code in ['BEP', 'CAP', 'BTF']) {
        expect(kPrerequisites[code], {'BEPC', 'BET'}, reason: code);
      }
    });

    test('aucun antécédent -> aucun diplôme trouvé, mais rien n\'est refusé', () {
      // L'élève a pu obtenir son BET dans un établissement hors E-PILOTE.
      // L'app le signale ; elle ne bloque pas l'inscription.
      final h = _history();
      expect(h.diplomaAmong(kPrerequisites['BAC_T']!), isNull);
      expect(h.isEmpty, isTrue);
    });

    test('le diplôme le plus récent est retenu en premier', () {
      // Le provider trie par année décroissante ; diplomaAmong prend le premier.
      final h = _history(exams: [
        _exam('BET', year: '2024-2025'),
        _exam('BEPC', year: '2021-2022'),
      ]);
      expect(h.diplomaAmong({'BEPC', 'BET'})!.yearLabel, '2024-2025');
    });
  });

  group('Stages — l\'attestation est la pièce qui compte', () {
    test('un stage sans attestation ne débloque pas le dossier de bac', () {
      final h = _history(stages: [_stage()]);
      expect(h.internships.single.hasAttestation, isFalse);
      expect(h.hasAttestation, isFalse);
    });

    test('un stage attesté débloque', () {
      final h = _history(stages: [_stage(attestation: DateTime(2025, 5, 12))]);
      expect(h.hasAttestation, isTrue);
    });

    test('un seul stage attesté suffit parmi plusieurs', () {
      final h = _history(stages: [
        _stage(),
        _stage(attestation: DateTime(2025, 5, 12)),
      ]);
      expect(h.hasAttestation, isTrue);
    });
  });

  group('StudentHistory — parcours complet', () {
    test('un parcours réel : BEPC -> BET -> stage -> bac en attente', () {
      final h = _history(
        exams: [
          _exam('BAC_T', result: 'en_attente', year: '2025-2026'),
          _exam('BET', year: '2023-2024'),
          _exam('BEPC', year: '2021-2022'),
        ],
        stages: [_stage(attestation: DateTime(2025, 5, 12))],
      );
      expect(h.isEmpty, isFalse);
      // BAC_T est en attente : il ne compte pas parmi les diplômes obtenus.
      expect(h.diplomas.map((e) => e.examCode), ['BET', 'BEPC']);
      // Le prérequis du bac est satisfait par le BET, le plus récent des deux.
      expect(h.diplomaAmong(kPrerequisites['BAC_T']!)!.examCode, 'BET');
      expect(h.hasAttestation, isTrue);
    });
  });
}
