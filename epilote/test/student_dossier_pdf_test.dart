import 'package:epilote/features/admin_groupe/providers/student_dossier_provider.dart';
import 'package:epilote/features/admin_groupe/providers/student_results_provider.dart';
import 'package:epilote/features/admin_groupe/services/student_dossier_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Génération RÉELLE du dossier de l'élève.
///
/// L'enseignement technique aligne beaucoup de matières : le tableau des
/// résultats est la partie du document qui peut grandir sans limite. Or un
/// cadre plus haut qu'une page ne se scinde pas — il fait boucler `MultiPage`
/// jusqu'à `TooManyPagesException`, et le dossier ne s'imprime PAS DU TOUT.
/// On construit donc le document pour de vrai, jusqu'au cas défavorable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));

  StudentDossier dossier({int tutors = 2, int incidents = 3}) => StudentDossier(
        id: 'eleve-1',
        fullName: 'Marie-Bénédicte Nkounkou Massamba',
        matricule: 'MAT-04-022',
        gender: 'F',
        dateOfBirth: DateTime(2010, 5, 9),
        nationality: 'Congolaise',
        isActive: true,
        school: const DossierSchool(
          name: 'Complexe Scolaire Départemental Étoile du Nord',
          address: 'Avenue de l\'École, Ouesso',
          city: 'Ouesso',
          department: 'Sangha',
          phone: '065268924',
          email: 'contact@epilote.cg',
          directorName: 'Gaston Bemba',
          directorPhone: '063561835',
        ),
        enrollment: const DossierEnrollment(
          classId: 'classe-1',
          academicYearId: 'annee-1',
          className: 'Terminale Technique Industrielle A',
          filiere: 'Maintenance des Systèmes Électromécaniques',
          cycleCode: 'lycee',
          levelCode: 'Tle',
          status: 'active',
          inscriptionType: 'new',
        ),
        tutors: [
          for (var i = 0; i < tutors; i++)
            DossierTutor(
              fullName: 'Responsable $i',
              relationship: 'mere',
              phonePrimary: '062541931',
              address: 'Quartier Plateau, Ouesso',
              profession: 'Enseignant(e)',
            ),
        ],
        teachers: const [],
        incidents: [
          for (var i = 0; i < incidents; i++)
            DossierIncident(
              date: DateTime(2026, 3, 12),
              type: 'retard',
              description: 'Retard répété en début de séance.',
              parentNotified: true,
            ),
        ],
      );

  StudentResults results(int subjectCount) => StudentResults(
        subjects: [
          for (var i = 0; i < subjectCount; i++)
            SubjectResult(
              subject: 'Matière professionnelle numéro $i',
              coefficient: 5,
              gradeCount: 2,
              average: 12.5,
              classAverage: 13.25,
            ),
        ],
        overall: 12.5,
        classOverall: 13.25,
      );

  test('un dossier sans résultats se génère quand même', () async {
    final bytes = await StudentDossierPdfService.buildPdf(
        groupName: 'METP', d: dossier(), results: null);
    expect(bytes.length, greaterThan(0));
  });

  test('un dossier de 12 matières — cas courant du technique', () async {
    final bytes = await StudentDossierPdfService.buildPdf(
        groupName: 'METP', d: dossier(), results: results(12));
    expect(bytes.length, greaterThan(0));
  });

  test('un dossier de 30 matières se génère sans exception', () async {
    final bytes = await StudentDossierPdfService.buildPdf(
      groupName: 'Ministère de l\'Enseignement Technique et Professionnel',
      d: dossier(tutors: 4, incidents: 8),
      results: results(30),
      distinction: const DossierDistinction(
        rank: 1,
        average: 18.6,
        mention: 'Excellent',
        scope: 'BET · filière Électrotechnique',
        sessionLabel: '2025-2026',
      ),
    );
    expect(bytes.length, greaterThan(0),
        reason: 'aucune section du dossier ne doit pouvoir bloquer le document');
  });
}
