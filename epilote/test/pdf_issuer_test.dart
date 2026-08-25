import 'package:epilote/core/services/official_pdf_kit.dart';
import 'package:epilote/features/students/providers/inscriptions_data_provider.dart';
import 'package:epilote/features/students/services/inscriptions_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DOCUMENT EST ÉMIS PAR L'ÉTABLISSEMENT, PAS PAR L'ÉDITEUR.
//
//  Les exports portaient « E-PILOTE CONGO » en en-tête. Une famille qui reçoit
//  une fiche d'inscription doit y lire le nom de l'école ; un document remonté
//  à la hiérarchie doit porter l'identité de qui le remonte.
//
//  Ce que ces tests tiennent :
//  • l'émetteur posé est bien celui qui ressort, et `null` rétablit l'identité
//    par défaut (cas du super_admin, qui édite au nom de la plateforme) ;
//  • un nom long — « Ministère de l'Enseignement Technique et Professionnel »
//    est le cas RÉEL, pas une valeur extrême — ne fait pas échouer l'export ;
//  • un émetteur sans logo produit quand même un document : hors ligne, le
//    logo peut manquer, jamais le document.
// ════════════════════════════════════════════════════════════════════════════

InscriptionRow _row(int i) => InscriptionRow(
      id: 'e$i',
      studentId: 's$i',
      firstName: 'Prénom$i',
      lastName: 'NOM$i',
      matricule: 'MAT-99-00$i',
      ine: null,
      gender: 'F',
      dateOfBirth: DateTime(2010, 5, 12),
      photoUrl: null,
      classId: 'c1',
      className: '3ème A',
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
  tearDown(() => OfficialPdfKit.setIssuer(null));

  group('émetteur des documents', () {
    test('l\'émetteur posé est celui qui ressort', () {
      OfficialPdfKit.setIssuer(const PdfIssuer(
          name: 'Groupe Scolaire Bethel', subtitle: 'Collège de Kinkala'));
      expect(OfficialPdfKit.issuer?.name, 'Groupe Scolaire Bethel');
      expect(OfficialPdfKit.issuer?.subtitle, 'Collège de Kinkala');
    });

    test('null rétablit l\'identité de la plateforme', () {
      OfficialPdfKit.setIssuer(const PdfIssuer(name: 'Groupe X'));
      OfficialPdfKit.setIssuer(null);
      expect(OfficialPdfKit.issuer, isNull,
          reason: 'Le super_admin édite au nom de la plateforme : son en-tête '
              'ne doit pas hériter du dernier groupe consulté.');
    });

    test('un nom long produit un document', () async {
      OfficialPdfKit.setIssuer(const PdfIssuer(
        name: 'Ministère de l\'Enseignement Technique et Professionnel',
        subtitle: 'Direction des Examens et Concours — Brazzaville',
      ));
      final bytes = await InscriptionsPdfService.buildPdf(
          rows: [for (var i = 0; i < 40; i++) _row(i)],
          yearLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('un émetteur sans logo produit un document', () async {
      OfficialPdfKit.setIssuer(const PdfIssuer(name: 'Groupe Scolaire Bethel'));
      final bytes = await InscriptionsPdfService.buildPdf(rows: [_row(1)]);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
