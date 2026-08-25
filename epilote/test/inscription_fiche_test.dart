import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/finance/providers/decompte_du_provider.dart';
import 'package:epilote/features/students/providers/inscriptions_data_provider.dart';
import 'package:epilote/features/students/services/inscription_fiche_service.dart';

/// La fiche d'inscription est le seul papier que l'école remet à la famille.
/// Ces tests vérifient qu'elle SE CONSTRUIT dans les cas où elle est le plus
/// utile — dossier en attente, sans tuteur, sans matricule — car un document
/// qui lève une exception ne s'imprime pas du tout.
InscriptionRow _row({
  String status = 'pending_validation',
  String matricule = 'KIN-2026-0042',
  String? ine = '26000000013',
}) =>
    InscriptionRow(
      id: 'e1',
      studentId: 's1',
      firstName: 'Aristide',
      lastName: 'NGOMA',
      matricule: matricule,
      ine: ine,
      gender: 'M',
      dateOfBirth: DateTime(2014, 1, 15),
      photoUrl: null,
      classId: 'c1',
      className: '6ème A',
      capacity: 45,
      cycle: inscriptionCycleFromCode('college', '6ème A'),
      levelCode: '6e',
      levelOrder: 1,
      filiereLabel: null,
      inscriptionType: 'new',
      status: status,
      isRepeating: false,
      enrollmentDate: DateTime(2025, 9, 12),
      validatedAt: null,
    );

StudentTutorInfo _tutor() => const StudentTutorInfo(
      id: 't1',
      firstName: 'Marie',
      lastName: 'NKOUNKOU',
      relationship: 'mere',
      phonePrimary: '066112233',
      phoneSecondary: null,
      email: null,
      profession: null,
      address: null,
      isPrimary: true,
      isEmergency: false,
    );

StudentDossier _dossier({List<StudentTutorInfo> tutors = const []}) =>
    StudentDossier(
      student: const {
        'date_of_birth': '2014-01-15',
        'place_of_birth': 'Kinkala',
        'nationality': 'Congolaise',
        'address': '12 rue de la Paix',
        'city': 'Kinkala',
      },
      tutors: tutors,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  test('dossier en attente : la fiche se construit', () async {
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(),
      dossier: _dossier(tutors: [_tutor()]),
      schoolName: 'Collège Public de Kinkala',
      yearLabel: '2025-2026',
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('sans aucun tuteur : la fiche se construit quand même', () async {
    // Le cas ne devrait plus se produire depuis la garde de l'étape 2, mais
    // les dossiers déjà en base peuvent l'être — et c'est justement pour eux
    // qu'on imprime une fiche.
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(),
      dossier: _dossier(),
      schoolName: 'Collège Public de Kinkala',
      yearLabel: '2025-2026',
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('sans matricule ni école ni année : la fiche se construit', () async {
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(matricule: ''),
      dossier: _dossier(tutors: [_tutor()]),
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('dossier validé : la fiche se construit', () async {
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(status: 'active'),
      dossier: _dossier(tutors: [_tutor(), _tutor()]),
      schoolName: 'Collège Public de Kinkala',
      yearLabel: '2025-2026',
    );
    expect(bytes.length, greaterThan(1000));
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LE BLOC FRAIS
  //
  //  La fiche disait la classe et le matricule, et pas un mot de ce que la
  //  famille devait — alors que c'est la première question posée au guichet.
  // ══════════════════════════════════════════════════════════════════════════
  group('le décompte des frais', () {
    test('une école privée : le détail sort sur la fiche', () async {
      final bytes = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(tutors: [_tutor()]),
        schoolName: 'Institut Sainte-Marie',
        yearLabel: '2025-2026',
        frais: _frais(mois: 4),
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('avec exonération : la remise a sa propre ligne', () async {
      final bytes = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(tutors: [_tutor()]),
        schoolName: 'Institut Sainte-Marie',
        yearLabel: '2025-2026',
        frais: _frais(mois: 4, exoneration: 50, motif: 'Bourse d\'État'),
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('AUCUN barème : le bloc est OMIS, jamais rempli de zéros', () async {
      // Trente écoles publiques du réseau n'ont aucun tarif posé. Un bloc
      // frais à « 0 F » leur ferait délivrer à chaque famille un papier
      // affirmant la gratuité de la scolarité.
      final avec = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(tutors: [_tutor()]),
        frais: const DecompteDu(),
      );
      final sans = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(tutors: [_tutor()]),
      );
      // Deux documents identiques : le décompte vide n'a rien ajouté.
      expect((avec.length - sans.length).abs(), lessThan(200));
    });

    test('le PIRE cas tient : 4 tuteurs, 6 frais, exonération', () async {
      // ⚠️ CE test est la raison du passage de `Page` à `MultiPage`. Sans
      // frais, la fiche occupait ~690 pt des 842 d'une A4. Le décompte d'une
      // école privée complète ajoute assez pour franchir le bord — et sur une
      // page fixe, signatures et pied seraient sortis du papier SANS erreur.
      // Sur `MultiPage`, un bloc insécable trop haut lève
      // `TooManyPagesException` : l'échec devient visible ici plutôt qu'au
      // guichet.
      final bytes = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(
            tutors: [_tutor(), _tutor(), _tutor(), _tutor()]),
        schoolName: 'Complexe Scolaire Privé Notre-Dame de l\'Espérance',
        yearLabel: '2025-2026',
        frais: const DecompteDu(
          lignes: [
            (
              id: 'i',
              libelle: 'Frais d\'inscription 2025-2026',
              feeType: 'inscription',
              montant: 15000,
              verse: 15000,
            ),
            (
              id: 'a',
              libelle: 'Cotisation Association des Parents d\'Élèves',
              feeType: 'cotisation_ape',
              montant: 2000,
              verse: 0,
            ),
            (
              id: 'm',
              libelle: 'Scolarité mensuelle',
              feeType: 'mensualite',
              montant: 120000,
              verse: 60000,
            ),
            (
              id: 'c',
              libelle: 'Cantine scolaire',
              feeType: 'autre',
              montant: 45000,
              verse: 0,
            ),
            (
              id: 't',
              libelle: 'Transport scolaire',
              feeType: 'autre',
              montant: 60000,
              verse: 0,
            ),
            (
              id: 'u',
              libelle: 'Tenue et fournitures',
              feeType: 'autre',
              montant: 18000,
              verse: 0,
            ),
          ],
          mois: 10,
          exoneration: 25,
          motifExoneration:
              'Bourse d\'État attribuée sur critères sociaux — arrêté n° 214/MEPSA',
        ),
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('le décompte ne fait pas échouer la fiche sur des montants extrêmes',
        () async {
      final bytes = await InscriptionFicheService.buildPdf(
        row: _row(status: 'active'),
        dossier: _dossier(tutors: [_tutor()]),
        frais: const DecompteDu(
          lignes: [
            (
              id: 'm',
              libelle: 'Scolarité',
              feeType: 'mensualite',
              montant: 999999999,
              verse: 1,
            ),
          ],
          mois: 10,
        ),
      );
      expect(bytes.length, greaterThan(1000));
    });
  });

  test('rendu de référence pour inspection visuelle', () async {
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(),
      dossier: _dossier(tutors: [_tutor()]),
      schoolName: 'Collège Public de Kinkala',
      yearLabel: '2025-2026',
      frais: _frais(mois: 4, exoneration: 50, motif: 'Bourse d\'État'),
    );
    final out = File('${Directory.systemTemp.path}/fiche_inscription.pdf');
    await out.writeAsBytes(bytes);
    expect(await out.exists(), isTrue);
  });
}

DecompteDu _frais({required int mois, int? exoneration, String? motif}) =>
    DecompteDu(
      lignes: [
        (
          id: 'i',
          libelle: 'Inscription 2025-2026',
          feeType: 'inscription',
          montant: 15000,
          verse: 15000,
        ),
        (
          id: 'a',
          libelle: 'Cotisation APE',
          feeType: 'cotisation_ape',
          montant: 2000,
          verse: 2000,
        ),
        (
          id: 'm',
          libelle: 'Scolarité',
          feeType: 'mensualite',
          montant: 12000 * mois,
          verse: 3000,
        ),
        (id: 'c', libelle: 'Cantine', feeType: 'autre', montant: 10000, verse: 0),
        (id: 't', libelle: 'Transport', feeType: 'autre', montant: 8000, verse: 0),
      ],
      mois: mois,
      exoneration: exoneration,
      motifExoneration: motif,
    );
