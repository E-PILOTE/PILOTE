// Le modèle que nous proposons doit être relu par notre propre lecteur.
//
// Il ne l'était plus vérifié nulle part : l'écriture et la lecture vivent dans
// deux fichiers, et un en-tête renommé d'un côté ne casse rien de visible de
// l'autre — jusqu'à ce qu'une école remplisse le modèle, l'importe, et voie
// trois cents lignes rejetées.
//
// Le texte du modèle est désormais produit par une fonction pure
// (`csvModeleImport`), séparée de l'écriture sur disque — qui, elle, passe par
// « Enregistrer sous » et ne peut donc pas tourner en test unitaire.

import 'dart:convert';

import 'package:epilote/features/students/providers/import_eleves_provider.dart';
import 'package:epilote/features/students/services/import_liste_eleves.dart';
import 'package:epilote/features/students/services/modele_import_csv.dart';
import 'package:flutter_test/flutter_test.dart';

const _classes = [
  ClasseCible('c1', '6e A', niveau: '6ème', filiere: 'Général'),
  ClasseCible('c2', '5e B', niveau: '5ème'),
];

void main() {
  group('Le modèle d\'import se relit par l\'import', () {
    test('ses deux lignes d\'exemple sont retenues, pas rejetées', () {
      final lu = lireFichierEleves(
        utf8.encode(csvModeleImport(_classes)),
        anneeReference: 2026,
      );

      expect(lu.retenues, hasLength(2),
          reason: lu.lignes.isEmpty
              ? 'aucune ligne lue'
              : lu.lignes.first.rejets.map((r) => r.texte).join(' / '));
    });

    test('les colonnes annoncées sont bien celles que le lecteur reconnaît',
        () {
      final lu = lireFichierEleves(
        utf8.encode(csvModeleImport(_classes)),
        anneeReference: 2026,
      );
      final reconnues = lu.colonnesReconnues.values.toSet();

      // Les quatre qui décident qu'une ligne est écrivable.
      expect(reconnues, contains(ChampImport.nom));
      expect(reconnues, contains(ChampImport.prenom));
      expect(reconnues, contains(ChampImport.dateNaissance));
      expect(reconnues, contains(ChampImport.sexe));
      // Et celle dont l'écart rejette des lignes entières.
      expect(reconnues, contains(ChampImport.classe));
    });

    test('la ligne d\'exemple porte une VRAIE classe de l\'école', () {
      // Un « 6e A » inventé n'existe pas forcément ici : l'exemple montrerait
      // alors le libellé qu'il ne faut PAS recopier.
      expect(csvModeleImport(_classes), contains('6e A'));
      expect(csvModeleImport(const []), contains('6e A'));
    });

    test('les exemples se dénoncent eux-mêmes', () {
      // Laissés dans le fichier, ils entreraient au registre comme des élèves.
      expect(csvModeleImport(_classes), contains('À SUPPRIMER'));
    });
  });

  group('La liste des classes de l\'école', () {
    test('porte le libellé exact, son niveau et sa filière', () {
      final csv = csvClassesEcole(_classes);

      expect(csv, contains('"Classe";"Niveau";"Filière"'));
      expect(csv, contains('"6e A";"6ème";"Général"'));
      // Filière absente : une cellule vide, jamais « null ».
      expect(csv, contains('"5e B";"5ème";""'));
    });
  });
}
