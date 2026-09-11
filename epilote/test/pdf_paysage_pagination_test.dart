// ════════════════════════════════════════════════════════════════════════════
//  QUATRE DOCUMENTS EN PAYSAGE NE SORTAIENT PAS PASSÉ UNE VINGTAINE DE LIGNES
//
//  ── LE MÉCANISME ───────────────────────────────────────────────────────────
//  `OfficialPdfKit.frame()` enveloppe son contenu dans un `Padding`, et un
//  `Padding` ne sait pas se scinder entre deux pages. Une table plus haute
//  qu'une feuille fait donc boucler `MultiPage` jusqu'à
//  `TooManyPagesException` : on n'obtient pas un document tronqué, on
//  n'obtient **AUCUN document**. Le remède existe — `tableSection`, qui
//  découpe en blocs paginables — mais quatre services ne l'employaient pas.
//
//  ── ET LE PIÈGE DANS LE PIÈGE (trouvé le 2026-09-10) ───────────────────────
//  `kRowsPerBlock` vaut 28 parce qu'il a été calculé sur une A4 **portrait**
//  (842 pt). Ces quatre documents sont en **paysage** : 595 pt. Le même bloc
//  de 28 lignes n'y tient pas — et un bloc qui déborde ramène exactement la
//  panne qu'on croyait avoir corrigée. D'où `kRowsPerBlockLandscape`.
//
//  ── POURQUOI ÇA COMPTE ─────────────────────────────────────────────────────
//  Ce sont les quatre listes que l'école IMPRIME et DÉPOSE :
//   · la liste des candidats — au guichet de la DEC, une session de BEPC en
//     porte 90 à 300 ;
//   · la liste du personnel — une école congolaise compte ~40 agents ;
//   · le journal de paie — autant de lignes, tous les mois ;
//   · l'état des stages — une terminale professionnelle part en entier.
//
//  Aucune ne se serait vue à la recette sur un jeu de démonstration.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/core/services/official_pdf_kit.dart';
import 'package:epilote/features/staff/providers/payroll_provider.dart';
import 'package:epilote/features/staff/providers/staff_directory_provider.dart';
import 'package:epilote/features/staff/services/payroll_pdf_service.dart';
import 'package:epilote/features/staff/services/personnel_export_service.dart';
import 'package:epilote/features/stages/providers/stages_provider.dart';
import 'package:epilote/features/stages/services/stage_export_service.dart';

StaffMember _agent(int i) => StaffMember(
      id: 'a$i',
      firstName: 'Jean-Baptiste',
      lastName: 'MAKOSSO-NGOMA $i',
      role: i.isEven ? 'enseignant' : 'surveillant',
      isActive: i % 7 != 0,
      phone: '+242 06 000 00 $i',
      employeeNumber: 'MAT-${i.toString().padLeft(4, '0')}',
      employmentStatus: 'permanent',
      teachingCycle: 'college',
    );

PayrollLine _paie(int i) => PayrollLine(
      id: 'p$i',
      staffId: 'a$i',
      staffName: 'MAKOSSO-NGOMA Jean-Baptiste $i',
      base: 150000,
      bonuses: 25000,
      deductions: 12000,
      net: 163000,
      status: i.isEven ? 'paid' : 'pending',
      method: 'especes',
    );

InternshipRow _stage(int i) => InternshipRow(
      id: 'i$i',
      studentName: 'NGOMA Aristide $i',
      className: 'Tle F3',
      classId: 'cl-1',
      filiereLabel: 'Électrotechnique',
      levelOrder: 12,
      companyName: 'Société Nationale d\'Électricité du Congo',
      title: 'Stage de fin de cycle',
      startDate: DateTime(2026, 5, 4),
      endDate: DateTime(2026, 6, 26),
      status: InternshipStatus.termine,
      hasAttestation: i.isEven,
      conventionSigned: true,
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Le seuil paysage est déclaré une fois, et il est plus bas', () {
    test('il existe, et il est inférieur au seuil portrait', () {
      expect(OfficialPdfKit.kRowsPerBlockLandscape,
          lessThan(OfficialPdfKit.kRowsPerBlock),
          reason: 'Une A4 paysage fait 595 pt de haut contre 842 : elle porte '
              'MOINS de lignes, jamais autant. Un seuil paysage supérieur ou '
              'égal au portrait ramène la panne qu\'il existe pour empêcher.');
      expect(OfficialPdfKit.kRowsPerBlockLandscape, greaterThan(5),
          reason: 'Un seuil trop bas hacherait la liste en dizaines de blocs '
              'de trois lignes, chacun avec son cadre et son titre.');
    });
  });

  group('La liste du PERSONNEL sort, quelle que soit la taille de l\'école',
      () {
    test('40 agents — une école congolaise ordinaire', () async {
      final o = await PersonnelExportService.buildPdf(
        agents: [for (var i = 0; i < 40; i++) _agent(i)],
        schoolName: 'CEG de Kinkala',
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('150 agents — un grand lycée technique', () async {
      final o = await PersonnelExportService.buildPdf(
        agents: [for (var i = 0; i < 150; i++) _agent(i)],
        schoolName: 'Lycée technique 1er Mai',
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('aucun agent : un document, pas une exception', () async {
      final o = await PersonnelExportService.buildPdf(
          agents: const [], schoolName: null);
      expect(o.lengthInBytes, greaterThan(1000));
    });
  });

  group('Le JOURNAL DE PAIE sort — c\'est la pièce classée chaque mois', () {
    test('40 bulletins', () async {
      final o = await PayrollPdfService.buildRegister(
        lines: [for (var i = 0; i < 40; i++) _paie(i)],
        month: 9,
        year: 2026,
        schoolName: 'CEG de Kinkala',
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('150 bulletins', () async {
      final o = await PayrollPdfService.buildRegister(
        lines: [for (var i = 0; i < 150; i++) _paie(i)],
        month: 9,
        year: 2026,
        schoolName: null,
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('un mois sans paie rend quand même le journal', () async {
      final o = await PayrollPdfService.buildRegister(
          lines: const [], month: 9, year: 2026, schoolName: null);
      expect(o.lengthInBytes, greaterThan(1000));
    });
  });

  group('L\'ÉTAT DES STAGES sort — une classe entière part en stage', () {
    test('35 stages — une terminale professionnelle', () async {
      final o = await StageExportService.buildStageListPdf(
        rows: [for (var i = 0; i < 35; i++) _stage(i)],
        schoolName: 'Lycée technique 1er Mai',
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('120 stages — plusieurs classes', () async {
      final o = await StageExportService.buildStageListPdf(
        rows: [for (var i = 0; i < 120; i++) _stage(i)],
        schoolName: null,
      );
      expect(o.lengthInBytes, greaterThan(1000));
    });

    test('aucun stage : un document, pas une exception', () async {
      final o = await StageExportService.buildStageListPdf(
          rows: const [], schoolName: null);
      expect(o.lengthInBytes, greaterThan(1000));
    });
  });
}
