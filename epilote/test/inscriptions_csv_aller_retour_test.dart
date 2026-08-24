// Une école exporte ses effectifs et les envoie à une autre — ou les ressort
// pour les corriger dans Excel avant de les réinjecter. C'est le geste de la
// fin d'année et celui du transfert.
//
// L'export ne portait pas la DATE DE NAISSANCE, que l'import tient pour
// obligatoire : notre propre fichier était rejeté à cent pour cent, et l'écran
// de contrôle affichait trois cents lignes rouges sans que personne comprenne.
//
// Ce test relit l'export avec le vrai lecteur d'import. Il échouera au premier
// en-tête qu'on retirerait ou renommerait sans y penser.

import 'dart:convert';

import 'package:epilote/features/students/services/import_liste_eleves.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les en-têtes ÉCRITES par `exportInscriptionsCsv`, dans leur ordre.
///
/// Recopiées ici volontairement : `exportInscriptionsCsv` écrit sur le disque
/// (`getApplicationDocumentsDirectory`), indisponible en test unitaire. Ce qui
/// compte — et ce que ce test verrouille — c'est que ces libellés-là soient
/// reconnus par le lecteur.
const _entetesExport = [
  'Matricule', 'INE', 'Nom', 'Prénom', 'Sexe',
  'Date de naissance', 'Lieu de naissance', 'Nationalité',
  'Classe', 'Cycle',
  'Type', 'Statut', 'Redoublant', 'Date inscription',
];

String _ligne(List<String> cells) =>
    cells.map((c) => '"${c.replaceAll('"', '""')}"').join(';');

void main() {
  group('L\'export du guichet se relit par l\'import', () {
    // Une ligne telle que l'export la produit pour un élève complet.
    final csv = '${_ligne(_entetesExport)}\n'
        '${_ligne([
          'MAT-0042', 'CG-2025-0001', 'NGOMA', 'Aïcha', 'F',
          '2011-03-12', 'Brazzaville', 'Congolaise',
          '6e A', 'Collège',
          'Nouvelle', 'Validée', 'Non', '2025-10-02',
        ])}\n';

    test('la ligne est retenue, pas rejetée', () {
      final lu = lireFichierEleves(utf8.encode(csv), anneeReference: 2026);

      expect(lu.retenues, hasLength(1),
          reason: lu.lignes.isEmpty
              ? 'aucune ligne lue'
              : lu.lignes.first.rejets.map((r) => r.texte).join(' / '));
    });

    test('les colonnes qui rendaient l\'aller-retour impossible sont lues', () {
      final lu = lireFichierEleves(utf8.encode(csv), anneeReference: 2026);
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
      final lu = lireFichierEleves(utf8.encode(csv), anneeReference: 2026);
      final l = lu.retenues.single;

      expect(l.nom, 'NGOMA');
      expect(l.prenom, 'Aïcha');
      expect(l.sexe, 'F');
      expect(l.dateNaissance, DateTime(2011, 3, 12));
      expect(l.ine, 'CG-2025-0001');
      expect(l.classeTexte, '6e A');
      expect(l.lieuNaissance, 'Brazzaville');
    });

    test('« Date inscription » n\'est pas prise pour la date de naissance', () {
      // Les deux en-têtes commencent par « Date ». Si le lecteur confondait,
      // il daterait la naissance de l'élève du jour de son inscription.
      final lu = lireFichierEleves(utf8.encode(csv), anneeReference: 2026);
      expect(lu.retenues.single.dateNaissance, DateTime(2011, 3, 12));
    });

    test('un élève sans date de naissance est refusé, et le dit', () {
      // Le comportement du lecteur reste STRICT : c'est l'export qu'on a
      // corrigé, pas l'exigence.
      final sansDate = '${_ligne(_entetesExport)}\n'
          '${_ligne([
            'MAT-0043', '', 'MABIALA', 'Jean', 'M',
            '', '', '',
            '6e A', 'Collège',
            'Nouvelle', 'Validée', 'Non', '2025-10-02',
          ])}\n';

      final lu = lireFichierEleves(utf8.encode(sansDate), anneeReference: 2026);
      expect(lu.retenues, isEmpty);
      expect(lu.lignes.single.rejets.map((r) => r.texte).join(),
          contains('Date de naissance'));
    });
  });
}
