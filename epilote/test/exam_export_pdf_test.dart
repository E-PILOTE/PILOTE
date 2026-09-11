// Les deux documents du module Examens sont ceux qu'on DÉPOSE À LA DEC : la
// liste officielle des candidats, et la fiche d'inscription qu'on ressort quand
// un parent conteste. Aucun test ne les construisait.
//
// ── LE DÉFAUT QUE CE FICHIER AURAIT ATTRAPÉ (trouvé le 2026-09-09) ───────────
// La liste déclarait NEUF colonnes et ne donnait que HUIT largeurs de `flex`.
// La neuvième — « Dossier », celle qui dit si le candidat est en règle — n'en
// avait aucune. Et la table était enveloppée dans `frame()`, qui ne sait pas se
// scinder entre deux pages : passé une feuille, `MultiPage` boucle jusqu'à
// `TooManyPagesException`, et l'on n'obtient AUCUN document. Une session de BEPC
// porte couramment 90 à 300 candidats.
//
// C'est le pire moment pour le découvrir : au guichet de la DEC, le jour du
// dépôt, avec la file derrière.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/examens/providers/candidate_file_provider.dart';
import 'package:epilote/features/examens/providers/exam_candidates_provider.dart';
import 'package:epilote/features/examens/services/exam_export_service.dart';

ExamCandidateRow _c(int i, {String? dossier = 'complet', String? ine}) =>
    ExamCandidateRow(
      id: 'c$i',
      studentId: 's$i',
      fullName: 'NGOMA Aristide Jean-Baptiste $i',
      matricule: 'KIN-2026-${i.toString().padLeft(4, '0')}',
      ine: ine ?? '260000000$i',
      dateOfBirth: DateTime(2009, 3, 14),
      gender: i.isEven ? 'F' : 'M',
      className: '3ème A',
      filiereLabel: 'Série C — Mathématiques et sciences physiques',
      cycleCode: 'college',
      levelCode: '3EME',
      levelOrder: 9,
      classId: 'cl-1',
      candidateNumber: '2026-BEPC-${i.toString().padLeft(5, '0')}',
      dossierStatus: dossier,
      missingCount: dossier == 'complet' ? 0 : 2,
      submittedAt: dossier == 'complet' ? DateTime(2026, 5, 2) : null,
      result: null,
      average: null,
      mention: null,
    );

CandidateFile _fiche() => CandidateFile(
      candidateId: 'c1',
      studentId: 's1',
      firstName: 'Aristide',
      lastName: 'NGOMA',
      matricule: 'KIN-2026-0001',
      ine: '2600000001',
      dateOfBirth: DateTime(2009, 3, 14),
      placeOfBirth: 'Kinkala',
      gender: 'M',
      nationality: 'Congolaise',
      photoUrl: null,
      className: '3ème A',
      filiereLabel: 'Série C',
      levelName: 'Troisième',
      candidateNumber: '2026-BEPC-00001',
      isRepeater: false,
      dossierStatus: 'complet',
      registeredAt: DateTime(2026, 4, 12),
      submittedAt: DateTime(2026, 5, 2),
      examName: 'Brevet d\'Études du Premier Cycle',
      examShortName: 'BEPC',
      tutelle: 'mepsa',
      yearLabel: '2026',
      writtenFrom: DateTime(2026, 6, 15),
      result: null,
      average: null,
      mention: null,
      decidedAt: null,
      resultSource: null,
      notes: null,
    );

Future<void> _liste(List<ExamCandidateRow> c) async {
  final octets = await ExamExportService.buildCandidateListPdf(
    candidates: c,
    examName: 'Brevet d\'Études du Premier Cycle',
    examShortName: 'BEPC',
    schoolName: 'CEG de Kinkala',
    tutelle: 'mepsa',
    yearLabel: '2026',
    writtenFrom: DateTime(2026, 6, 15),
  );
  expect(octets.lengthInBytes, greaterThan(1000));
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('La liste des candidats se construit', () {
    test('une session ordinaire — 90 candidats', () async {
      await _liste([for (var i = 0; i < 90; i++) _c(i)]);
    });

    test('une GROSSE session — 300 candidats, plusieurs feuilles', () async {
      // ⚠️ Le cas qui faisait lever avant `tableSection`. 300 candidats ne
      // tiennent pas sur une page ; `frame()` ne se scindant pas, le document
      // ne sortait pas du tout.
      await _liste([for (var i = 0; i < 300; i++) _c(i)]);
    });

    test('une session VIDE rend un document, pas une exception', () async {
      // L'école qui n'a encore inscrit personne doit pouvoir imprimer sa
      // liste — vide, mais avec l'en-tête et la mention qui le dit.
      await _liste(const []);
    });

    test('les données manquantes ne font pas échouer le document', () async {
      await _liste([
        _c(1, dossier: null, ine: null),
        _c(2, dossier: 'incomplet'),
      ]);
    });
  });

  group('La fiche d\'inscription se construit', () {
    test('avec ses pièces', () async {
      final octets = await ExamExportService.buildCandidateFilePdf(
        c: _fiche(),
        schoolName: 'CEG de Kinkala',
        pieces: const [
          (label: 'Acte de naissance', state: 'Fournie'),
          (label: 'Photo d\'identité', state: 'Fournie'),
          (label: 'Certificat de scolarité', state: 'Manquante'),
        ],
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });

    test('sans aucune pièce déclarée', () async {
      final octets = await ExamExportService.buildCandidateFilePdf(
        c: _fiche(),
        schoolName: null,
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });
  });
}
