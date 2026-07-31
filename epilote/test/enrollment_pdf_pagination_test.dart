import 'package:epilote/features/students/providers/inscriptions_data_provider.dart';
import 'package:epilote/features/students/services/inscriptions_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'EXPORT DOIT SORTIR, MÊME POUR UNE CLASSE PLEINE.
//
//  `official_pdf_kit.dart` documente le piège en toutes lettres : un contenu
//  enveloppé dans un `Padding` ne sait pas se scinder entre deux pages, et
//  `MultiPage` boucle alors jusqu'à `TooManyPagesException` — le document ne
//  sort PAS DU TOUT. Pas une page tronquée : rien.
//
//  Une classe congolaise compte couramment quarante à soixante élèves. Le seuil
//  se franchit donc au premier export réel, et il se franchit en démonstration
//  avant de se franchir en production.
//
//  Ces tests montent volontairement jusqu'à 60 élèves dans UNE classe, puis
//  180 répartis sur trois : c'est la charge normale, pas un cas extrême.
// ════════════════════════════════════════════════════════════════════════════

InscriptionRow _row(int i, String className) => InscriptionRow(
      id: 'e$i',
      studentId: 's$i',
      firstName: 'Prénom$i',
      lastName: 'NOM$i',
      matricule: 'MAT-99-${i.toString().padLeft(3, '0')}',
      gender: i.isEven ? 'M' : 'F',
      dateOfBirth: DateTime(2010, 1 + (i % 12), 1 + (i % 28)),
      photoUrl: null,
      classId: 'c-$className',
      className: className,
      capacity: 60,
      cycle: const InscriptionCycle('college', 'Collège', 3),
      levelCode: '3e',
      levelOrder: 4,
      filiereLabel: null,
      inscriptionType: 'new',
      status: 'pending_validation',
      isRepeating: false,
      enrollmentDate: DateTime(2025, 9, 16),
      validatedAt: null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  group('export PDF des inscriptions', () {
    test('une classe de 60 élèves produit un document', () async {
      final rows = [for (var i = 0; i < 60; i++) _row(i, '3ème A')];
      final bytes = await InscriptionsPdfService.buildPdf(
          rows: rows, schoolName: 'Collège de test', yearLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000),
          reason: 'Le document doit sortir : une classe pleine est la norme, '
              'pas un cas limite.');
    });

    test('trois classes de 60 élèves produisent un document', () async {
      final rows = [
        for (final c in ['3ème A', '3ème B', '3ème C'])
          for (var i = 0; i < 60; i++) _row(i, c),
      ];
      final bytes = await InscriptionsPdfService.buildPdf(
          rows: rows, schoolName: 'Collège de test', yearLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('un effectif vide ne fait pas échouer l\'export', () async {
      final bytes = await InscriptionsPdfService.buildPdf(rows: const []);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
