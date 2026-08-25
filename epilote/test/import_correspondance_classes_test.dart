// Une école a créé « 6e A » ; le classeur de la secrétaire porte « 6A ». Le
// rapprochement est délibérément STRICT — envoyer un enfant en 6ᵉ B au lieu de
// 6ᵉ A ne se découvrirait qu'au conseil de classe — et jusqu'ici cette
// sévérité n'avait aucune porte de sortie : quarante lignes rejetées, un
// message « corrigez le fichier », et il fallait tout recommencer dans Excel.
//
// Ces tests fixent l'unité de réparation : UN libellé, pas quarante lignes.

import 'package:epilote/features/students/providers/import_eleves_provider.dart';
import 'package:epilote/features/students/services/import_liste_eleves.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;

LigneImport _ligne({String? classe}) => LigneImport(
      numero: ++_n,
      nom: 'NGOMA',
      prenom: 'Aïcha',
      dateNaissance: DateTime(2011, 3, 12),
      sexe: 'F',
      classeTexte: classe,
    );

PreparationImport _prep(List<LigneResolue> lignes) => PreparationImport(
      lecture: const LectureImport(
        lignes: [],
        colonnesReconnues: {},
        colonnesIgnorees: [],
        separateur: ';',
      ),
      lignes: lignes,
      classeParDefaut: null,
    );

void main() {
  group('libellesInconnus', () {
    test('regroupe les lignes par libellé, pas une entrée par élève', () {
      final p = _prep([
        for (var i = 0; i < 40; i++)
          LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
      ]);

      expect(p.libellesInconnus, hasLength(1),
          reason: 'quarante élèves en « 6A » sont UN problème');
      expect(p.libellesInconnus.single.libelle, '6A');
      expect(p.libellesInconnus.single.lignes, 40);
    });

    test('la casse ne fabrique pas deux aiguillages', () {
      // Le regroupement passe par `cleClasse`, qui met en minuscules : sans
      // cela, un classeur mêlant « 6A » et « 6a » ferait refaire deux fois le
      // même geste pour une seule et même classe.
      final p = _prep([
        LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
        LigneResolue(_ligne(classe: '6a'), classeInconnue: '6a'),
        LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
      ]);

      expect(p.libellesInconnus, hasLength(1));
      expect(p.libellesInconnus.single.lignes, 3);
    });

    test('une espace en plus reste un libellé distinct — et c\'est voulu', () {
      // `cleClasse` ne supprime pas les espaces : « 6A » vaut « 6a », mais
      // « 6 A » vaut « 6 a ». Deux graphies, deux lignes dans le panneau.
      //
      // On NE corrige PAS ce point ici : `cleClasse` sert aussi au
      // rapprochement strict avec les classes réelles, et l'assouplir pour
      // gagner une ligne d'affichage reviendrait à toucher la règle qui
      // empêche d'envoyer un enfant dans la mauvaise section. Deux aiguillages
      // à poser coûtent deux clics ; une classe fausse coûte un trimestre.
      final p = _prep([
        LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
        LigneResolue(_ligne(classe: '6 A'), classeInconnue: '6 A'),
      ]);

      expect(p.libellesInconnus, hasLength(2));
      expect(p.libellesInconnus.map((i) => i.lignes), [1, 1]);
    });

    test('garde le libellé TEL QUEL, pas sa forme normalisée', () {
      // C'est ce que la secrétaire a tapé dans son classeur : une forme
      // normalisée ne l'aiderait pas à reconnaître sa propre saisie.
      final p = _prep([
        LigneResolue(_ligne(classe: '6ÈME  a'), classeInconnue: '6ÈME  a'),
      ]);
      expect(p.libellesInconnus.single.libelle, '6ÈME  a');
    });

    test('trie du plus bloquant au moins bloquant', () {
      final p = _prep([
        LigneResolue(_ligne(classe: '5B'), classeInconnue: '5B'),
        for (var i = 0; i < 12; i++)
          LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
        for (var i = 0; i < 4; i++)
          LigneResolue(_ligne(classe: '4C'), classeInconnue: '4C'),
      ]);

      expect(p.libellesInconnus.map((i) => i.libelle), ['6A', '4C', '5B']);
      expect(p.libellesInconnus.map((i) => i.lignes), [12, 4, 1]);
    });

    test('une ligne résolue ne figure pas parmi les inconnus', () {
      final p = _prep([
        LigneResolue(_ligne(classe: '6e A'),
            classeId: 'c1', classeNom: '6e A'),
        LigneResolue(_ligne(classe: '6A'), classeInconnue: '6A'),
      ]);

      expect(p.libellesInconnus, hasLength(1));
      expect(p.libellesInconnus.single.libelle, '6A');
      expect(p.retenues, hasLength(1));
      expect(p.rejetees, hasLength(1));
    });

    test('aucun libellé inconnu quand tout se rattache', () {
      final p = _prep([
        LigneResolue(_ligne(classe: '6e A'),
            classeId: 'c1', classeNom: '6e A'),
      ]);
      expect(p.libellesInconnus, isEmpty);
    });
  });

  group('cleClasse — ce que la correspondance regroupe déjà seule', () {
    test('les ordinaux se rejoignent', () {
      expect(cleClasse('6e A'), cleClasse('6ème A'));
      expect(cleClasse('6e A'), cleClasse('6EME A'));
    });

    test('mais deux sections restent distinctes', () {
      // C'est toute la raison d'être de l'aiguillage manuel : le code refuse
      // de décider que « 6A » vaut « 6e A », et laisse un humain le dire.
      expect(cleClasse('6e A') == cleClasse('6e B'), isFalse);
    });
  });
}
