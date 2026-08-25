// Les attestations sont les seuls papiers que l'école ÉMET. Deux choses
// doivent tenir : elles ne se délivrent que quand elles sont VRAIES, et elles
// se construisent dans les cas dégradés — un document qui lève une exception ne
// s'imprime pas du tout, et c'est au guichet qu'on s'en aperçoit.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/staff/services/attestation_travail_pdf_service.dart';
import 'package:epilote/features/students/services/attestations_pdf_service.dart';

AttestationEleve _eleve({String? ine = '26000000013', String? gender = 'M'}) =>
    AttestationEleve(
      firstName: 'Aristide',
      lastName: 'Ngoma',
      className: '6ème A',
      ine: ine,
      matricule: 'KIN-2026-0042',
      gender: gender,
      dateOfBirth: DateTime(2014, 1, 15),
      placeOfBirth: 'Kinkala',
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Un papier ne se délivre que s\'il est vrai', () {
    test('le certificat de scolarité exige une inscription ACTIVE', () {
      expect(peutDelivrerScolarite('active'), isTrue);
      for (final s in ['withdrawn', 'transferred', 'graduated',
                       'pending_validation', 'rejected', null]) {
        expect(peutDelivrerScolarite(s), isFalse,
            reason: 'un élève « $s » n\'est pas inscrit');
      }
    });

    test('le certificat de radiation exige une inscription CLOSE', () {
      for (final s in ['withdrawn', 'transferred', 'graduated']) {
        expect(peutDelivrerRadiation(s), isTrue);
      }
      // Le faux symétrique : radier sur le papier un élève encore présent.
      expect(peutDelivrerRadiation('active'), isFalse);
      expect(peutDelivrerRadiation('pending_validation'), isFalse);
      expect(peutDelivrerRadiation(null), isFalse);
    });

    test('les deux certificats ne sont jamais délivrables ensemble', () {
      for (final s in ['active', 'withdrawn', 'transferred', 'graduated',
                       'pending_validation', 'rejected', null]) {
        expect(peutDelivrerScolarite(s) && peutDelivrerRadiation(s), isFalse,
            reason: 'statut « $s »');
      }
    });

    test('l\'attestation de travail suppose un agent en service', () {
      expect(peutDelivrerAttestationTravail(isActive: true), isTrue);
      expect(peutDelivrerAttestationTravail(isActive: false), isFalse);
    });
  });

  group('Accord en genre', () {
    test('une élève est « née » et « inscrite »', () {
      final f = _eleve(gender: 'F');
      expect(f.ne, 'née');
      expect(f.inscrit, 'inscrite');
      expect(f.radie, 'radiée');
    });

    test('un genre inconnu retombe sur le masculin, jamais sur du vide', () {
      final x = _eleve(gender: null);
      expect(x.ne, 'né');
      expect(x.inscrit, 'inscrit');
    });

    test('le nom se lit NOM Prénom', () {
      expect(_eleve().fullName, 'NGOMA Aristide');
    });
  });

  group('Les documents se construisent', () {
    test('certificat de scolarité', () async {
      final bytes = await AttestationsPdfService.certificatScolarite(
        eleve: _eleve(),
        schoolName: 'CEG de Kinkala',
        yearLabel: '2025-2026',
        city: 'Kinkala',
        signataire: 'Léontine BOUITY',
        fonction: 'Le Directeur',
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('certificat de scolarité sans signataire ni ville', () async {
      // Le cas d'un secrétaire qui imprime : la plateforme ne met aucun nom.
      final bytes = await AttestationsPdfService.certificatScolarite(
        eleve: _eleve(),
        schoolName: 'CEG de Kinkala',
        yearLabel: '2025-2026',
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('certificat de radiation SANS identifiant national', () async {
      // Le cas le plus utile et le plus fragile : une inscription saisie hors
      // ligne n'a pas encore d'INE. Le papier doit quand même sortir, en le
      // disant.
      final bytes = await AttestationsPdfService.certificatRadiation(
        eleve: _eleve(ine: null),
        schoolName: 'CEG de Kinkala',
        yearLabel: '2025-2026',
        motif: 'transfert',
        dateSortie: DateTime(2026, 3, 12),
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('certificat de radiation sans motif ni date', () async {
      final bytes = await AttestationsPdfService.certificatRadiation(
        eleve: _eleve(),
        schoolName: 'CEG de Kinkala',
        yearLabel: '2025-2026',
        motif: null,
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('attestation de travail, agent sans date d\'entrée connue', () async {
      // `hire_date` est vide sur toute la base réelle : c'est le cas NORMAL,
      // pas le cas limite.
      final bytes = await AttestationTravailPdfService.build(
        agent: const AttestationAgent(
          firstName: 'Jean-Claude',
          lastName: 'Mabiala',
          fonction: 'Enseignant',
          employeeNumber: 'ENS5-MEPSA',
          employmentStatus: 'fonctionnaire',
        ),
        schoolName: 'CEG de Kinkala',
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('attestation de service rendu, agent parti', () async {
      final bytes = await AttestationTravailPdfService.build(
        agent: AttestationAgent(
          firstName: 'Jean-Claude',
          lastName: 'Mabiala',
          fonction: 'Enseignant',
          gender: 'M',
          grade: 'A2',
          echelon: '3',
          hireDate: DateTime(2019, 10, 1),
          departureDate: DateTime(2026, 6, 30),
        ),
        schoolName: 'CEG de Kinkala',
        serviceRendu: true,
      );
      expect(bytes.length, greaterThan(1000));
    });
  });
}
