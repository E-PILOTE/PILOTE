// Une école exporte son effectif et l'envoie à une autre — ou le ressort pour
// le corriger dans Excel avant de le réinjecter. C'est le geste de la fin
// d'année et celui du transfert.
//
// L'export de la page Élèves ne portait pas la DATE DE NAISSANCE, que l'import
// tient pour obligatoire : le fichier produit par E-PILOTE était rejeté par
// E-PILOTE, à cent pour cent. Il n'emportait pas non plus l'INE — l'identifiant
// qui recoud la scolarité d'un enfant d'une école à l'autre, et qu'omettre
// revient à couper ce fil au moment précis où il sert.
//
// Le même défaut avait été corrigé sur l'export du guichet ; il était resté ici.
// Ce test relit l'export avec le VRAI lecteur d'import, et échouera au premier
// en-tête qu'on retirerait ou renommerait sans y penser.

import 'dart:convert';

import 'package:epilote/features/students/providers/students_registry_provider.dart';
import 'package:epilote/features/students/services/import_liste_eleves.dart';
import 'package:flutter_test/flutter_test.dart';

String _ligne(List<String> cells) =>
    cells.map((c) => '"${c.replaceAll('"', '""')}"').join(';');

final _eleve = StudentRow(
  id: 'e1',
  firstName: 'Aïcha',
  lastName: 'NGOMA',
  matricule: 'MAT-0042',
  ine: '26000001234',
  gender: 'F',
  dateOfBirth: DateTime(2011, 3, 12),
  placeOfBirth: 'Brazzaville',
  nationality: 'Congolaise',
  photoUrl: null,
  isBoarder: true,
  hasScholarship: false,
  hasSocialAid: true,
  isAffecte: false,
  enrollmentId: 'i1',
  enrollmentStatus: 'active',
  classId: 'c1',
  className: '6e A',
  cycleCode: 'college',
  levelCode: '6e',
  levelOrder: 1,
  filiereLabel: null,
  hasPrimaryTutor: true,
);

/// Le fichier tel que `exportStudentsCsv` l'écrit — mêmes en-têtes, mêmes
/// cellules. L'écriture disque elle-même (`getApplicationDocumentsDirectory`)
/// n'est pas disponible en test unitaire ; ce qui compte, et ce que ce test
/// verrouille, c'est que ce contenu-là soit relu.
String _csvDe(List<StudentRow> rows) {
  final b = StringBuffer()..writeln(_ligne(kEnTetesExportEleves));
  for (final r in rows) {
    b.writeln(_ligne(ligneExportEleve(r)));
  }
  return b.toString();
}

void main() {
  group('L\'export de l\'effectif se relit par l\'import', () {
    test('la ligne est retenue, pas rejetée', () {
      final lu = lireFichierEleves(utf8.encode(_csvDe([_eleve])),
          anneeReference: 2026);

      expect(lu.retenues, hasLength(1),
          reason: lu.lignes.isEmpty
              ? 'aucune ligne lue'
              : lu.lignes.first.rejets.map((r) => r.texte).join(' / '));
    });

    test('les colonnes qui rendaient l\'aller-retour impossible sont lues', () {
      final lu = lireFichierEleves(utf8.encode(_csvDe([_eleve])),
          anneeReference: 2026);
      final reconnues = lu.colonnesReconnues.values.toSet();

      // La date de naissance est la colonne dont l'absence rejetait TOUT.
      expect(reconnues, contains(ChampImport.dateNaissance));
      // L'INE recoud la scolarité d'un enfant d'une école à l'autre.
      expect(reconnues, contains(ChampImport.ine));
      expect(reconnues, contains(ChampImport.nom));
      expect(reconnues, contains(ChampImport.prenom));
      expect(reconnues, contains(ChampImport.sexe));
      expect(reconnues, contains(ChampImport.classe));
    });

    test('les valeurs traversent intactes', () {
      final lu = lireFichierEleves(utf8.encode(_csvDe([_eleve])),
          anneeReference: 2026);
      final l = lu.retenues.single;

      expect(l.nom, 'NGOMA');
      expect(l.prenom, 'Aïcha');
      expect(l.sexe, 'F');
      expect(l.dateNaissance, DateTime(2011, 3, 12));
      expect(l.ine, '26000001234');
      expect(l.classeTexte, '6e A');
      expect(l.lieuNaissance, 'Brazzaville');
    });

    test('l\'en-tête ne porte plus « Âge »', () {
      // Un âge se recalcule, et il VIEILLIT dans le fichier : réimporté l'année
      // suivante, il aurait décrit des enfants qui ont grandi. La date de
      // naissance, elle, reste vraie.
      expect(kEnTetesExportEleves, isNot(contains('Âge')));
      expect(kEnTetesExportEleves, contains('Date de naissance'));
    });

    test('autant de cellules que d\'en-têtes', () {
      // Un décalage d'une colonne mettrait le lieu de naissance dans la
      // nationalité, sans qu'aucun import ne s'en plaigne.
      expect(ligneExportEleve(_eleve), hasLength(kEnTetesExportEleves.length));
    });

    test('un élève sans date de naissance est refusé, et le dit', () {
      // Le comportement du lecteur reste STRICT : c'est l'export qu'on a
      // corrigé, pas l'exigence.
      const sansDate = StudentRow(
        id: 'e2',
        firstName: 'Jean',
        lastName: 'MABIALA',
        matricule: 'MAT-0043',
        ine: null,
        gender: 'M',
        dateOfBirth: null,
        placeOfBirth: null,
        nationality: null,
        photoUrl: null,
        isBoarder: false,
        hasScholarship: false,
        hasSocialAid: false,
        isAffecte: false,
        enrollmentId: 'i2',
        enrollmentStatus: 'active',
        classId: 'c1',
        className: '6e A',
        cycleCode: 'college',
        levelCode: '6e',
        levelOrder: 1,
        filiereLabel: null,
        hasPrimaryTutor: false,
      );

      final lu = lireFichierEleves(utf8.encode(_csvDe([sansDate])),
          anneeReference: 2026);
      expect(lu.retenues, isEmpty);
      expect(lu.lignes.single.rejets.map((r) => r.texte).join(),
          contains('Date de naissance'));
    });
  });
}
