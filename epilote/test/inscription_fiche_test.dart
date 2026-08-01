import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/students/providers/inscriptions_data_provider.dart';
import 'package:epilote/features/students/services/inscription_fiche_service.dart';

/// La fiche d'inscription est le seul papier que l'école remet à la famille.
/// Ces tests vérifient qu'elle SE CONSTRUIT dans les cas où elle est le plus
/// utile — dossier en attente, sans tuteur, sans matricule — car un document
/// qui lève une exception ne s'imprime pas du tout.
InscriptionRow _row({
  String status = 'pending_validation',
  String matricule = 'KIN-2026-0042',
}) =>
    InscriptionRow(
      id: 'e1',
      studentId: 's1',
      firstName: 'Aristide',
      lastName: 'NGOMA',
      matricule: matricule,
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

  test('rendu de référence pour inspection visuelle', () async {
    final bytes = await InscriptionFicheService.buildPdf(
      row: _row(),
      dossier: _dossier(tutors: [_tutor()]),
      schoolName: 'Collège Public de Kinkala',
      yearLabel: '2025-2026',
    );
    final out = File('${Directory.systemTemp.path}/fiche_inscription.pdf');
    await out.writeAsBytes(bytes);
    expect(await out.exists(), isTrue);
  });
}
