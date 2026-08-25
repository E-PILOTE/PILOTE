// Le sélecteur de classe affiche « 6e A (24/25) » — l'état AVANT. Sélectionner
// trente élèves et les y déplacer portait la classe à cinquante-quatre sans un
// mot : la seule information qui comptait (ce qu'elle contiendra APRÈS)
// n'apparaissait nulle part, et la surcharge se découvrait dans la salle.
//
// L'alerte informe, elle n'interdit pas : les effectifs réels dépassent
// régulièrement la capacité déclarée, et une plateforme qui le refuserait serait
// contournée dès le premier jour.

import 'package:epilote/features/students/services/capacite_classe.dart';
import 'package:flutter_test/flutter_test.dart';

DebordementClasse? _test({
  int effectif = 24,
  int? capacite = 25,
  int aDeplacer = 30,
}) =>
    debordementApresDeplacement(
      className: '6e A',
      effectifActuel: effectif,
      capacite: capacite,
      aDeplacer: aDeplacer,
    );

void main() {
  group('Quand la classe va déborder', () {
    test('le déplacement qui dépasse la capacité est signalé', () {
      expect(_test(), isNotNull);
    });

    test('le message dit AVANT, APRÈS, et de combien on dépasse', () {
      final d = _test()!;
      expect(d.avant, 24);
      expect(d.apres, 54);
      expect(d.capacite, 25);
      expect(d.exces, 29);
      expect(d.message, contains('6e A'));
      expect(d.message, contains('54'));
      expect(d.message, contains('25'));
    });

    test('dépasser d\'un seul élève suffit à prévenir', () {
      final d = _test(effectif: 25, capacite: 25, aDeplacer: 1);
      expect(d, isNotNull);
      expect(d!.exces, 1);
    });
  });

  group('Quand il n\'y a rien à signaler', () {
    test('le déplacement qui tient dans la capacité passe en silence', () {
      expect(_test(effectif: 10, capacite: 25, aDeplacer: 5), isNull);
    });

    test('remplir la classe EXACTEMENT n\'est pas un débordement', () {
      expect(_test(effectif: 20, capacite: 25, aDeplacer: 5), isNull);
    });

    test('une capacité non renseignée ne déclenche rien', () {
      // ⚠️ `null` n'est PAS une capacité de zéro : c'est une capacité qu'on
      // ignore. Prévenir d'un dépassement qu'on n'a aucun moyen de constater
      // ferait crier l'alerte sur toutes les classes non paramétrées, et on
      // apprendrait à cliquer « Confirmer » sans lire.
      expect(_test(capacite: null), isNull);
      expect(_test(capacite: 0), isNull);
    });

    test('ne déplacer personne ne déclenche rien, même classe pleine', () {
      // L'alerte porte sur le GESTE en cours, pas sur l'état des lieux.
      expect(_test(effectif: 60, capacite: 25, aDeplacer: 0), isNull);
    });

    test('une classe déjà surchargée où l\'on ajoute encore prévient', () {
      final d = _test(effectif: 60, capacite: 25, aDeplacer: 3);
      expect(d, isNotNull);
      expect(d!.apres, 63);
    });
  });
}
