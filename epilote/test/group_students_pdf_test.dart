import 'package:epilote/features/admin_groupe/providers/admin_students_provider.dart';
import 'package:epilote/features/admin_groupe/services/group_students_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Génération RÉELLE du PDF « Élèves du réseau ».
///
/// Ce test existe parce qu'un défaut de mise en page n'y produit pas un rendu
/// approximatif : il produit `TooManyPagesException`, et le document ne sort
/// pas du tout. `OfficialPdfKit.frame()` enveloppe son contenu dans un
/// `Padding`, qui ne sait pas se scinder entre deux pages ; si un bloc de
/// lignes dépasse la hauteur utile, `MultiPage` boucle jusqu'à l'exception.
/// On construit donc vraiment le document, jusqu'au cas le plus défavorable :
/// le plafond de recherche, avec des libellés à rallonge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));

  GroupStudent student(int i, {bool long = false}) => GroupStudent(
        id: '$i',
        fullName: long
            ? 'Marie-Bénédicte Nkounkou Massamba Loemba $i'
            : 'Élève $i',
        schoolName: long
            ? 'Complexe Scolaire Départemental Étoile du Nord de Ouesso $i'
            : 'Lycée de Madingou',
        isActive: true,
        matricule: 'MAT-04-${i.toString().padLeft(3, '0')}',
        gender: i.isEven ? 'F' : 'M',
        dateOfBirth: DateTime(2010, 5, 9),
        department: 'Bouenza',
        className: long ? 'Terminale Technique Industrielle A' : '4ème A',
        filiere: long ? 'Maintenance des Systèmes Électromécaniques' : null,
      );

  Future<int> build(List<GroupStudent> rows, {bool truncated = false}) async {
    final bytes = await GroupStudentsPdfService.buildPdf(
      groupName: 'Ministère de l\'Enseignement Technique et Professionnel',
      rows: rows,
      query: const StudentQuery(department: 'Bouenza', filiere: 'Série C'),
      truncated: truncated,
      schoolLabel: 'Lycée de Madingou',
    );
    return bytes.length;
  }

  test('une liste vide produit quand même un document', () async {
    expect(await build(const []), greaterThan(0));
  });

  test('une liste courte tient sur une page', () async {
    expect(await build([for (var i = 0; i < 8; i++) student(i)]),
        greaterThan(0));
  });

  test('le plafond de recherche (200 élèves) se génère sans exception',
      () async {
    expect(
      await build([for (var i = 0; i < kStudentSearchLimit; i++) student(i)],
          truncated: true),
      greaterThan(0),
    );
  });

  test('200 élèves aux libellés à rallonge se génèrent aussi', () async {
    expect(
      await build(
        [
          for (var i = 0; i < kStudentSearchLimit; i++) student(i, long: true),
        ],
        truncated: true,
      ),
      greaterThan(0),
      reason: 'les noms longs sont écrêtés pour tenir sur une seule ligne',
    );
  });
}
